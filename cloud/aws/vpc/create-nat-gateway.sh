#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-nat-gateway.sh [OPTIONS]

Create a NAT Gateway in a subnet, optionally allocating Elastic IP automatically.

Options:
  --subnet-id ID            Subnet ID (required)
  --allocation-id ID        Existing Elastic IP allocation ID
  --create-eip              Allocate new Elastic IP for public NAT if needed (default)
  --connectivity-type TYPE  public|private (default: public)
  --name NAME               Name tag value
  --tag KEY=VALUE           Tag pair (repeatable)
  --tags CSV                Comma-separated KEY=VALUE pairs
  --if-not-exists           Reuse NAT gateway in same subnet if available/pending
  --wait                    Wait for NAT to become available (default)
  --no-wait                 Return immediately after create
  --timeout SEC             Wait timeout in seconds (default: 1200)
  --poll-interval SEC       Wait poll interval seconds (default: 15)
  --region REGION           AWS region
  --profile PROFILE         AWS CLI profile
  --dry-run                 Print planned commands only
  -h, --help                Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-nat-gateway] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_subnet_id() {
  [[ "$1" =~ ^subnet-[a-f0-9]{8,17}$ ]]
}

validate_allocation_id() {
  [[ "$1" =~ ^eipalloc-[a-f0-9]{8,17}$ ]]
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

find_existing_nat() {
  aws "${aws_options[@]}" ec2 describe-nat-gateways \
    --filter Name=subnet-id,Values="$subnet_id" Name=state,Values=pending,available \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2> /dev/null || true
}

wait_for_nat_available() {
  local start_time elapsed state
  start_time="$(date +%s)"

  while true; do
    state="$(aws "${aws_options[@]}" ec2 describe-nat-gateways --nat-gateway-ids "$nat_gateway_id" --query 'NatGateways[0].State' --output text 2> /dev/null || true)"
    case "$state" in
      available) return 0 ;;
      failed) die "NAT gateway entered failed state: $nat_gateway_id" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for NAT gateway availability: $nat_gateway_id"
    fi

    sleep "$poll_interval_seconds"
  done
}

subnet_id=""
allocation_id=""
create_eip=true
connectivity_type="public"
nat_name=""
tag_pairs=()
if_not_exists=false
wait_enabled=true
timeout_seconds=1200
poll_interval_seconds=15
region=""
profile=""
dry_run=false

while (($#)); do
  case "$1" in
    --subnet-id)
      shift
      (($#)) || die "--subnet-id requires a value"
      validate_subnet_id "$1" || die "invalid subnet ID: $1"
      subnet_id="$1"
      ;;
    --allocation-id)
      shift
      (($#)) || die "--allocation-id requires a value"
      validate_allocation_id "$1" || die "invalid allocation ID: $1"
      allocation_id="$1"
      ;;
    --create-eip)
      create_eip=true
      ;;
    --connectivity-type)
      shift
      (($#)) || die "--connectivity-type requires a value"
      case "$1" in
        public | private) connectivity_type="$1" ;;
        *) die "invalid connectivity type: $1 (expected public|private)" ;;
      esac
      ;;
    --name)
      shift
      (($#)) || die "--name requires a value"
      nat_name="$1"
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

[[ -n "$subnet_id" ]] || die "--subnet-id is required"
command_exists aws || die "aws CLI is required but not found"

if [[ "$connectivity_type" == "private" && -n "$allocation_id" ]]; then
  die "--allocation-id is not used with --connectivity-type private"
fi

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

aws "${aws_options[@]}" ec2 describe-subnets --subnet-ids "$subnet_id" > /dev/null 2>&1 || die "subnet not found or inaccessible: $subnet_id"

existing_nat="$(find_existing_nat)"
if [[ "$existing_nat" != "None" && -n "$existing_nat" ]]; then
  if $if_not_exists; then
    log "found existing NAT gateway in subnet: $existing_nat"
    printf '%s\n' "$existing_nat"
    exit 0
  fi
  die "NAT gateway already exists in subnet: $existing_nat"
fi

if [[ "$connectivity_type" == "public" && -z "$allocation_id" ]]; then
  if ! $create_eip; then
    die "public NAT requires --allocation-id or --create-eip"
  fi

  if $dry_run; then
    run_cmd aws "${aws_options[@]}" ec2 allocate-address --domain vpc
    allocation_id="eipalloc-DRYRUN"
  else
    allocation_id="$(aws "${aws_options[@]}" ec2 allocate-address --domain vpc --query 'AllocationId' --output text)"
    [[ -n "$allocation_id" && "$allocation_id" != "None" ]] || die "failed to allocate Elastic IP"
    log "allocated Elastic IP: $allocation_id"
  fi
fi

create_cmd=(aws "${aws_options[@]}" ec2 create-nat-gateway --subnet-id "$subnet_id" --connectivity-type "$connectivity_type")
[[ -n "$allocation_id" ]] && create_cmd+=(--allocation-id "$allocation_id")

if $dry_run; then
  run_cmd "${create_cmd[@]}"
  printf '%s\n' "nat-DRYRUN"
  exit 0
fi

nat_gateway_id="$("${create_cmd[@]}" --query 'NatGateway.NatGatewayId' --output text)"
[[ -n "$nat_gateway_id" && "$nat_gateway_id" != "None" ]] || die "failed to create NAT gateway"
log "created NAT gateway: $nat_gateway_id"

if [[ -n "$nat_name" || ${#tag_pairs[@]} -gt 0 ]]; then
  tag_args=()
  [[ -n "$nat_name" ]] && tag_args+=("Key=Name,Value=${nat_name}")
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    tag_args+=("Key=${tag_key},Value=${tag_value}")
  done
  run_cmd aws "${aws_options[@]}" ec2 create-tags --resources "$nat_gateway_id" --tags "${tag_args[@]}"
fi

if $wait_enabled; then
  wait_for_nat_available
fi

printf '%s\n' "$nat_gateway_id"
exit 0
