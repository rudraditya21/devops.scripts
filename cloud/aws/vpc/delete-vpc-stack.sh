#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: delete-vpc-stack.sh [OPTIONS]

Delete VPC stack resources in dependency-safe order and remove the VPC.

Options:
  --vpc-id ID                 VPC ID to delete (required)
  --if-missing                Return success if VPC does not exist
  --delete-internet-gateways  Delete attached internet gateways after detach (default)
  --keep-internet-gateways    Detach internet gateways but keep them
  --release-eips              Release Elastic IPs from deleted NAT gateways
  --wait                      Wait for NAT gateways to delete (default)
  --no-wait                   Skip NAT wait
  --timeout SEC               Wait timeout in seconds (default: 1800)
  --poll-interval SEC         Wait poll interval in seconds (default: 15)
  --region REGION             AWS region
  --profile PROFILE           AWS CLI profile
  --yes                       Required for non-dry-run deletion
  --dry-run                   Print planned commands only
  -h, --help                  Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [delete-vpc-stack] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_vpc_id() {
  [[ "$1" =~ ^vpc-[a-f0-9]{8,17}$ ]]
}

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
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

wait_for_nat_deleted() {
  local nat_gateway_id="$1"
  local start_time elapsed state
  start_time="$(date +%s)"

  while true; do
    state="$(aws "${aws_options[@]}" ec2 describe-nat-gateways --nat-gateway-ids "$nat_gateway_id" --query 'NatGateways[0].State' --output text 2> /dev/null || true)"
    if [[ -z "$state" || "$state" == "None" || "$state" == "deleted" ]]; then
      return 0
    fi

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for NAT gateway deletion: $nat_gateway_id"
    fi

    sleep "$poll_interval_seconds"
  done
}

vpc_id=""
if_missing=false
delete_internet_gateways=true
release_eips=false
wait_enabled=true
timeout_seconds=1800
poll_interval_seconds=15
region=""
profile=""
yes=false
dry_run=false

while (($#)); do
  case "$1" in
    --vpc-id)
      shift
      (($#)) || die "--vpc-id requires a value"
      validate_vpc_id "$1" || die "invalid VPC ID: $1"
      vpc_id="$1"
      ;;
    --if-missing)
      if_missing=true
      ;;
    --delete-internet-gateways)
      delete_internet_gateways=true
      ;;
    --keep-internet-gateways)
      delete_internet_gateways=false
      ;;
    --release-eips)
      release_eips=true
      ;;
    --wait)
      wait_enabled=true
      ;;
    --no-wait)
      wait_enabled=false
      ;;
    --timeout)
      shift
      (($#)) || die "--timeout requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--timeout must be a positive integer"
      timeout_seconds="$1"
      ;;
    --poll-interval)
      shift
      (($#)) || die "--poll-interval requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--poll-interval must be a positive integer"
      poll_interval_seconds="$1"
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
    --yes)
      yes=true
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
command_exists aws || die "aws CLI is required but not found"

if ! $dry_run && ! $yes; then
  die "--yes is required for deletion"
fi

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

if ! aws "${aws_options[@]}" ec2 describe-vpcs --vpc-ids "$vpc_id" > /dev/null 2>&1; then
  if $if_missing; then
    log "VPC not found, skipping: $vpc_id"
    exit 0
  fi
  die "VPC not found or inaccessible: $vpc_id"
fi

nat_ids=()
nat_allocations=()
while read -r nat_id; do
  [[ -n "$nat_id" ]] || continue
  nat_ids+=("$nat_id")

  while read -r alloc; do
    [[ -n "$alloc" ]] || continue
    nat_allocations+=("$alloc")
  done < <(aws "${aws_options[@]}" ec2 describe-nat-gateways --nat-gateway-ids "$nat_id" --query 'NatGateways[0].NatGatewayAddresses[].AllocationId' --output text | tr '\t' '\n')

done < <(aws "${aws_options[@]}" ec2 describe-nat-gateways --filter Name=vpc-id,Values="$vpc_id" Name=state,Values=pending,available,failed --query 'NatGateways[].NatGatewayId' --output text | tr '\t' '\n')

for nat_id in "${nat_ids[@]}"; do
  run_cmd aws "${aws_options[@]}" ec2 delete-nat-gateway --nat-gateway-id "$nat_id" > /dev/null
  log "delete requested for NAT gateway: $nat_id"
  if $wait_enabled && ! $dry_run; then
    wait_for_nat_deleted "$nat_id"
  fi
done

if $release_eips; then
  released=()
  for alloc in "${nat_allocations[@]}"; do
    [[ "$alloc" =~ ^eipalloc- ]] || continue
    if array_contains "$alloc" "${released[@]}"; then
      continue
    fi
    run_cmd aws "${aws_options[@]}" ec2 release-address --allocation-id "$alloc"
    released+=("$alloc")
    log "released Elastic IP allocation: $alloc"
  done
fi

while read -r rtb_id; do
  [[ -n "$rtb_id" ]] || continue
  # shellcheck disable=SC2016
  main_assoc_query='length(RouteTables[0].Associations[?Main==`true`])'
  is_main_count="$(aws "${aws_options[@]}" ec2 describe-route-tables --route-table-ids "$rtb_id" --query "$main_assoc_query" --output text)"
  if [[ "$is_main_count" != "0" ]]; then
    continue
  fi

  while read -r assoc_id; do
    [[ -n "$assoc_id" ]] || continue
    run_cmd aws "${aws_options[@]}" ec2 disassociate-route-table --association-id "$assoc_id" > /dev/null
    # shellcheck disable=SC2016
    assoc_query='RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId'
  done < <(aws "${aws_options[@]}" ec2 describe-route-tables --route-table-ids "$rtb_id" --query "$assoc_query" --output text | tr '\t' '\n')

  run_cmd aws "${aws_options[@]}" ec2 delete-route-table --route-table-id "$rtb_id"
  log "deleted route table: $rtb_id"
done < <(aws "${aws_options[@]}" ec2 describe-route-tables --filters Name=vpc-id,Values="$vpc_id" --query 'RouteTables[].RouteTableId' --output text | tr '\t' '\n')

while read -r subnet_id; do
  [[ -n "$subnet_id" ]] || continue
  run_cmd aws "${aws_options[@]}" ec2 delete-subnet --subnet-id "$subnet_id"
  log "deleted subnet: $subnet_id"
done < <(aws "${aws_options[@]}" ec2 describe-subnets --filters Name=vpc-id,Values="$vpc_id" --query 'Subnets[].SubnetId' --output text | tr '\t' '\n')

while read -r nacl_id; do
  [[ -n "$nacl_id" ]] || continue
  run_cmd aws "${aws_options[@]}" ec2 delete-network-acl --network-acl-id "$nacl_id"
  log "deleted network ACL: $nacl_id"
  # shellcheck disable=SC2016
  nacl_query='NetworkAcls[?IsDefault==`false`].NetworkAclId'
done < <(aws "${aws_options[@]}" ec2 describe-network-acls --filters Name=vpc-id,Values="$vpc_id" --query "$nacl_query" --output text | tr '\t' '\n')

while read -r sg_id; do
  [[ -n "$sg_id" ]] || continue
  run_cmd aws "${aws_options[@]}" ec2 delete-security-group --group-id "$sg_id"
  log "deleted security group: $sg_id"
  # shellcheck disable=SC2016
  sg_query='SecurityGroups[?GroupName!=`default`].GroupId'
done < <(aws "${aws_options[@]}" ec2 describe-security-groups --filters Name=vpc-id,Values="$vpc_id" --query "$sg_query" --output text | tr '\t' '\n')

while read -r igw_id; do
  [[ -n "$igw_id" ]] || continue
  run_cmd aws "${aws_options[@]}" ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id"
  log "detached internet gateway: $igw_id"

  if $delete_internet_gateways; then
    run_cmd aws "${aws_options[@]}" ec2 delete-internet-gateway --internet-gateway-id "$igw_id"
    log "deleted internet gateway: $igw_id"
  fi
done < <(aws "${aws_options[@]}" ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text | tr '\t' '\n')

run_cmd aws "${aws_options[@]}" ec2 delete-vpc --vpc-id "$vpc_id"
log "deleted VPC: $vpc_id"

exit 0
