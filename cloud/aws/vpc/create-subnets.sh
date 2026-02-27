#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-subnets.sh [OPTIONS]

Create one or more VPC subnets from structured subnet specs.

Options:
  --vpc-id ID              VPC ID (required)
  --subnet SPEC            Subnet spec (repeatable): name=NAME,cidr=CIDR,az=AZ,public=true|false
  --tag KEY=VALUE          Tag pair applied to all created subnets (repeatable)
  --tags CSV               Comma-separated KEY=VALUE pairs for all created subnets
  --if-not-exists          Reuse subnet if same CIDR already exists in VPC
  --region REGION          AWS region
  --profile PROFILE        AWS CLI profile
  --dry-run                Print planned commands only
  -h, --help               Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-subnets] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

normalize_bool() {
  case "$1" in
    true | 1 | yes | on) printf 'true' ;;
    false | 0 | no | off) printf 'false' ;;
    *) die "invalid boolean value: $1 (use true/false)" ;;
  esac
}

validate_vpc_id() {
  [[ "$1" =~ ^vpc-[a-f0-9]{8,17}$ ]]
}

validate_cidr() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]
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

parse_subnet_spec() {
  local spec="$1"
  subnet_name=""
  subnet_cidr=""
  subnet_az=""
  subnet_public="false"

  IFS=',' read -r -a fields <<< "$spec"
  for field in "${fields[@]}"; do
    field="$(trim_spaces "$field")"
    [[ "$field" == *=* ]] || die "invalid subnet spec field: $field"
    key="${field%%=*}"
    value="${field#*=}"

    case "$key" in
      name) subnet_name="$value" ;;
      cidr)
        validate_cidr "$value" || die "invalid subnet CIDR in spec: $value"
        subnet_cidr="$value"
        ;;
      az) subnet_az="$value" ;;
      public) subnet_public="$(normalize_bool "$value")" ;;
      *) die "unknown subnet spec key: $key" ;;
    esac
  done

  [[ -n "$subnet_cidr" ]] || die "subnet spec missing required field: cidr"
}

find_existing_subnet_by_cidr() {
  local cidr="$1"
  aws "${aws_options[@]}" ec2 describe-subnets \
    --filters Name=vpc-id,Values="$vpc_id" Name=cidr-block,Values="$cidr" \
    --query 'Subnets[0].SubnetId' \
    --output text 2> /dev/null || true
}

vpc_id=""
subnet_specs=()
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
    --subnet)
      shift
      (($#)) || die "--subnet requires a value"
      subnet_specs+=("$1")
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
((${#subnet_specs[@]} > 0)) || die "at least one --subnet spec is required"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

aws "${aws_options[@]}" ec2 describe-vpcs --vpc-ids "$vpc_id" > /dev/null 2>&1 || die "VPC not found or inaccessible: $vpc_id"

rows=()
for spec in "${subnet_specs[@]}"; do
  parse_subnet_spec "$spec"

  subnet_id="$(find_existing_subnet_by_cidr "$subnet_cidr")"
  if [[ "$subnet_id" != "None" && -n "$subnet_id" ]]; then
    if $if_not_exists; then
      log "subnet exists for CIDR $subnet_cidr: $subnet_id"
      rows+=("$subnet_id|$subnet_cidr|$subnet_az|$subnet_public|existing")
      continue
    fi
    die "subnet with CIDR already exists: $subnet_id"
  fi

  if $dry_run; then
    run_cmd aws "${aws_options[@]}" ec2 create-subnet --vpc-id "$vpc_id" --cidr-block "$subnet_cidr"
    [[ -n "$subnet_az" ]] && run_cmd aws "${aws_options[@]}" ec2 create-subnet --vpc-id "$vpc_id" --cidr-block "$subnet_cidr" --availability-zone "$subnet_az"
    if [[ "$subnet_public" == "true" ]]; then
      run_cmd aws "${aws_options[@]}" ec2 modify-subnet-attribute --subnet-id subnet-DRYRUN --map-public-ip-on-launch "Value=true"
    fi
    rows+=("subnet-DRYRUN|$subnet_cidr|$subnet_az|$subnet_public|created")
    continue
  fi

  create_cmd=(aws "${aws_options[@]}" ec2 create-subnet --vpc-id "$vpc_id" --cidr-block "$subnet_cidr")
  [[ -n "$subnet_az" ]] && create_cmd+=(--availability-zone "$subnet_az")
  subnet_id="$("${create_cmd[@]}" --query 'Subnet.SubnetId' --output text)"
  [[ -n "$subnet_id" && "$subnet_id" != "None" ]] || die "failed to create subnet for CIDR $subnet_cidr"

  if [[ "$subnet_public" == "true" ]]; then
    run_cmd aws "${aws_options[@]}" ec2 modify-subnet-attribute --subnet-id "$subnet_id" --map-public-ip-on-launch "Value=true"
  fi

  combined_tags=()
  [[ -n "$subnet_name" ]] && combined_tags+=("Key=Name,Value=${subnet_name}")
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    combined_tags+=("Key=${tag_key},Value=${tag_value}")
  done
  if ((${#combined_tags[@]} > 0)); then
    run_cmd aws "${aws_options[@]}" ec2 create-tags --resources "$subnet_id" --tags "${combined_tags[@]}"
  fi

  rows+=("$subnet_id|$subnet_cidr|$subnet_az|$subnet_public|created")
done

printf '%-20s %-18s %-15s %-7s %s\n' "SUBNET_ID" "CIDR" "AZ" "PUBLIC" "STATUS"
printf '%-20s %-18s %-15s %-7s %s\n' "---------" "----" "--" "------" "------"
for row in "${rows[@]}"; do
  subnet_id="${row%%|*}"
  rest="${row#*|}"
  subnet_cidr="${rest%%|*}"
  rest="${rest#*|}"
  subnet_az="${rest%%|*}"
  rest="${rest#*|}"
  subnet_public="${rest%%|*}"
  status="${rest#*|}"
  printf '%-20s %-18s %-15s %-7s %s\n' "$subnet_id" "$subnet_cidr" "$subnet_az" "$subnet_public" "$status"
done

exit 0
