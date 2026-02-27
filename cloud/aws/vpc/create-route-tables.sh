#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-route-tables.sh [OPTIONS]

Create and wire public/private route tables for a VPC.

Options:
  --vpc-id ID                  VPC ID (required)
  --name-prefix PREFIX         Name prefix for route tables (default: vpc)
  --public-subnet-ids CSV      Public subnet IDs to associate
  --private-subnet-ids CSV     Private subnet IDs to associate
  --internet-gateway-id ID     Internet gateway ID for public route table
  --nat-gateway-id ID          NAT gateway ID for private route table
  --tag KEY=VALUE              Tag pair applied to created/reused route tables (repeatable)
  --tags CSV                   Comma-separated KEY=VALUE pairs
  --if-not-exists              Reuse route table by Name tag when present
  --region REGION              AWS region
  --profile PROFILE            AWS CLI profile
  --dry-run                    Print planned commands only
  -h, --help                   Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-route-tables] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_vpc_id() {
  [[ "$1" =~ ^vpc-[a-f0-9]{8,17}$ ]]
}

validate_subnet_id() {
  [[ "$1" =~ ^subnet-[a-f0-9]{8,17}$ ]]
}

validate_igw_id() {
  [[ "$1" =~ ^igw-[a-f0-9]{8,17}$ ]]
}

validate_nat_id() {
  [[ "$1" =~ ^nat-[a-f0-9]{8,17}$ ]]
}

validate_tag_pair() {
  [[ "$1" =~ ^[^=]+=[^=].*$ ]]
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

parse_tag_pair() {
  local pair="$1"
  tag_key="${pair%%=*}"
  tag_value="${pair#*=}"
}

find_route_table_by_name() {
  local table_name="$1"
  aws "${aws_options[@]}" ec2 describe-route-tables \
    --filters Name=vpc-id,Values="$vpc_id" Name=tag:Name,Values="$table_name" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2> /dev/null || true
}

ensure_default_route() {
  local route_table_id="$1"
  local target_type="$2"
  local target_id="$3"

  if $dry_run; then
    if [[ "$target_type" == "igw" ]]; then
      run_cmd aws "${aws_options[@]}" ec2 create-route --route-table-id "$route_table_id" --destination-cidr-block 0.0.0.0/0 --gateway-id "$target_id"
    else
      run_cmd aws "${aws_options[@]}" ec2 create-route --route-table-id "$route_table_id" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$target_id"
    fi
    return 0
  fi

  set +e
  if [[ "$target_type" == "igw" ]]; then
    output="$(aws "${aws_options[@]}" ec2 create-route --route-table-id "$route_table_id" --destination-cidr-block 0.0.0.0/0 --gateway-id "$target_id" 2>&1)"
  else
    output="$(aws "${aws_options[@]}" ec2 create-route --route-table-id "$route_table_id" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$target_id" 2>&1)"
  fi
  status=$?
  set -e

  if ((status == 0)); then
    return 0
  fi

  if grep -q 'RouteAlreadyExists' <<< "$output"; then
    log "default route already exists in $route_table_id"
    return 0
  fi

  printf '%s\n' "$output" >&2
  die "failed to create default route for table $route_table_id"
}

associate_subnet() {
  local route_table_id="$1"
  local subnet_id="$2"

  if $dry_run; then
    run_cmd aws "${aws_options[@]}" ec2 associate-route-table --route-table-id "$route_table_id" --subnet-id "$subnet_id"
    return 0
  fi

  set +e
  output="$(aws "${aws_options[@]}" ec2 associate-route-table --route-table-id "$route_table_id" --subnet-id "$subnet_id" 2>&1)"
  status=$?
  set -e

  if ((status == 0)); then
    return 0
  fi

  if grep -q 'Resource.AlreadyAssociated' <<< "$output"; then
    log "subnet already associated: $subnet_id"
    return 0
  fi

  printf '%s\n' "$output" >&2
  die "failed to associate subnet $subnet_id with route table $route_table_id"
}

ensure_tags() {
  local route_table_id="$1"
  local route_table_name="$2"

  tag_args=("Key=Name,Value=${route_table_name}")
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    tag_args+=("Key=${tag_key},Value=${tag_value}")
  done
  run_cmd aws "${aws_options[@]}" ec2 create-tags --resources "$route_table_id" --tags "${tag_args[@]}"
}

vpc_id=""
name_prefix="vpc"
public_subnet_ids=()
private_subnet_ids=()
internet_gateway_id=""
nat_gateway_id=""
tag_pairs=()
if_not_exists=false
region=""
profile=""
dry_run=false

while (($#)); do
  case "$1" in
    --vpc-id)
      shift
      (($#)) || die "--vpc-id requires a value"
      validate_vpc_id "$1" || die "invalid VPC ID: $1"
      vpc_id="$1"
      ;;
    --name-prefix)
      shift
      (($#)) || die "--name-prefix requires a value"
      name_prefix="$1"
      ;;
    --public-subnet-ids)
      shift
      (($#)) || die "--public-subnet-ids requires a value"
      IFS=',' read -r -a parsed_public <<< "$1"
      for value in "${parsed_public[@]}"; do
        value="$(trim_spaces "$value")"
        [[ -n "$value" ]] || continue
        validate_subnet_id "$value" || die "invalid subnet ID: $value"
        public_subnet_ids+=("$value")
      done
      ;;
    --private-subnet-ids)
      shift
      (($#)) || die "--private-subnet-ids requires a value"
      IFS=',' read -r -a parsed_private <<< "$1"
      for value in "${parsed_private[@]}"; do
        value="$(trim_spaces "$value")"
        [[ -n "$value" ]] || continue
        validate_subnet_id "$value" || die "invalid subnet ID: $value"
        private_subnet_ids+=("$value")
      done
      ;;
    --internet-gateway-id)
      shift
      (($#)) || die "--internet-gateway-id requires a value"
      validate_igw_id "$1" || die "invalid internet gateway ID: $1"
      internet_gateway_id="$1"
      ;;
    --nat-gateway-id)
      shift
      (($#)) || die "--nat-gateway-id requires a value"
      validate_nat_id "$1" || die "invalid NAT gateway ID: $1"
      nat_gateway_id="$1"
      ;;
    --tag)
      shift
      (($#)) || die "--tag requires a value"
      validate_tag_pair "$1" || die "invalid --tag format: $1"
      tag_pairs+=("$1")
      ;;
    --tags)
      shift
      (($#)) || die "--tags requires a value"
      IFS=',' read -r -a parsed_tags <<< "$1"
      for pair in "${parsed_tags[@]}"; do
        pair="$(trim_spaces "$pair")"
        [[ -n "$pair" ]] || continue
        validate_tag_pair "$pair" || die "invalid tag in --tags: $pair"
        tag_pairs+=("$pair")
      done
      ;;
    --if-not-exists)
      if_not_exists=true
      ;;
    --region)
      shift
      (($#)) || die "--region requires a value"
      region="$1"
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
      ;;
    --dry-run)
      dry_run=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

[[ -n "$vpc_id" ]] || die "--vpc-id is required"
if ((${#public_subnet_ids[@]} > 0)) && [[ -z "$internet_gateway_id" ]]; then
  die "--internet-gateway-id is required when --public-subnet-ids is provided"
fi
if ((${#private_subnet_ids[@]} > 0)) && [[ -z "$nat_gateway_id" ]]; then
  die "--nat-gateway-id is required when --private-subnet-ids is provided"
fi
if ((${#public_subnet_ids[@]} == 0 && ${#private_subnet_ids[@]} == 0)); then
  die "at least one subnet set is required (--public-subnet-ids and/or --private-subnet-ids)"
fi
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

aws "${aws_options[@]}" ec2 describe-vpcs --vpc-ids "$vpc_id" > /dev/null 2>&1 || die "VPC not found or inaccessible: $vpc_id"

rows=()

if ((${#public_subnet_ids[@]} > 0)); then
  public_name="${name_prefix}-public-rt"
  public_rt_id=""

  if $if_not_exists; then
    public_rt_id="$(find_route_table_by_name "$public_name")"
    [[ "$public_rt_id" == "None" ]] && public_rt_id=""
  fi

  if [[ -z "$public_rt_id" ]]; then
    if $dry_run; then
      run_cmd aws "${aws_options[@]}" ec2 create-route-table --vpc-id "$vpc_id"
      public_rt_id="rtb-DRYRUN-PUBLIC"
    else
      public_rt_id="$(aws "${aws_options[@]}" ec2 create-route-table --vpc-id "$vpc_id" --query 'RouteTable.RouteTableId' --output text)"
      [[ -n "$public_rt_id" && "$public_rt_id" != "None" ]] || die "failed to create public route table"
    fi
    log "public route table created: $public_rt_id"
  else
    log "reusing public route table: $public_rt_id"
  fi

  ensure_tags "$public_rt_id" "$public_name"
  ensure_default_route "$public_rt_id" "igw" "$internet_gateway_id"

  for subnet_id in "${public_subnet_ids[@]}"; do
    associate_subnet "$public_rt_id" "$subnet_id"
  done

  rows+=("public|$public_rt_id|${#public_subnet_ids[@]}")
fi

if ((${#private_subnet_ids[@]} > 0)); then
  private_name="${name_prefix}-private-rt"
  private_rt_id=""

  if $if_not_exists; then
    private_rt_id="$(find_route_table_by_name "$private_name")"
    [[ "$private_rt_id" == "None" ]] && private_rt_id=""
  fi

  if [[ -z "$private_rt_id" ]]; then
    if $dry_run; then
      run_cmd aws "${aws_options[@]}" ec2 create-route-table --vpc-id "$vpc_id"
      private_rt_id="rtb-DRYRUN-PRIVATE"
    else
      private_rt_id="$(aws "${aws_options[@]}" ec2 create-route-table --vpc-id "$vpc_id" --query 'RouteTable.RouteTableId' --output text)"
      [[ -n "$private_rt_id" && "$private_rt_id" != "None" ]] || die "failed to create private route table"
    fi
    log "private route table created: $private_rt_id"
  else
    log "reusing private route table: $private_rt_id"
  fi

  ensure_tags "$private_rt_id" "$private_name"
  ensure_default_route "$private_rt_id" "nat" "$nat_gateway_id"

  for subnet_id in "${private_subnet_ids[@]}"; do
    associate_subnet "$private_rt_id" "$subnet_id"
  done

  rows+=("private|$private_rt_id|${#private_subnet_ids[@]}")
fi

printf '%-8s %-22s %s\n' "TYPE" "ROUTE_TABLE_ID" "SUBNET_ASSOCIATIONS"
printf '%-8s %-22s %s\n' "----" "--------------" "-------------------"
for row in "${rows[@]}"; do
  table_type="${row%%|*}"
  rest="${row#*|}"
  route_table_id="${rest%%|*}"
  subnet_count="${rest#*|}"
  printf '%-8s %-22s %s\n' "$table_type" "$route_table_id" "$subnet_count"
done

exit 0
