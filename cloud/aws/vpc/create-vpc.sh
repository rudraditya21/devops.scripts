#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-vpc.sh [OPTIONS]

Create an AWS VPC with DNS settings and optional tags.

Options:
  --cidr CIDR                VPC CIDR block (required)
  --name NAME                Name tag value
  --tenancy MODE             default|dedicated (default: default)
  --enable-dns-support BOOL  true|false (default: true)
  --enable-dns-hostnames BOOL true|false (default: true)
  --tag KEY=VALUE            Tag pair (repeatable)
  --tags CSV                 Comma-separated KEY=VALUE pairs
  --if-not-exists            Reuse existing VPC matched by CIDR/name
  --wait                     Wait for VPC state=available (default)
  --no-wait                  Return immediately after create
  --timeout SEC              Wait timeout in seconds (default: 180)
  --poll-interval SEC        Wait poll interval in seconds (default: 5)
  --region REGION            AWS region
  --profile PROFILE          AWS CLI profile
  --dry-run                  Print planned commands only
  -h, --help                 Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-vpc] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

find_existing_vpc() {
  local filters=("Name=cidr,Values=${cidr_block}")

  if [[ -n "$vpc_name" ]]; then
    filters+=("Name=tag:Name,Values=${vpc_name}")
  fi

  aws "${aws_options[@]}" ec2 describe-vpcs \
    --filters "${filters[@]}" \
    --query 'Vpcs[0].VpcId' \
    --output text 2> /dev/null || true
}

wait_for_vpc_available() {
  local start_time elapsed state
  start_time="$(date +%s)"

  while true; do
    state="$(aws "${aws_options[@]}" ec2 describe-vpcs --vpc-ids "$vpc_id" --query 'Vpcs[0].State' --output text 2> /dev/null || true)"
    [[ "$state" == "available" ]] && return 0

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for VPC to become available: $vpc_id"
    fi

    sleep "$poll_interval_seconds"
  done
}

cidr_block=""
vpc_name=""
tenancy="default"
dns_support="true"
dns_hostnames="true"
tag_pairs=()
if_not_exists=false
wait_enabled=true
timeout_seconds=180
poll_interval_seconds=5
region=""
profile=""
dry_run=false

while (($#)); do
  case "$1" in
    --cidr)
      shift
      (($#)) || die "--cidr requires a value"
      validate_cidr "$1" || die "invalid CIDR format: $1"
      cidr_block="$1"
      ;;
    --name)
      shift
      (($#)) || die "--name requires a value"
      vpc_name="$1"
      ;;
    --tenancy)
      shift
      (($#)) || die "--tenancy requires a value"
      case "$1" in
        default | dedicated) tenancy="$1" ;;
        *) die "invalid tenancy: $1 (expected default|dedicated)" ;;
      esac
      ;;
    --enable-dns-support)
      shift
      (($#)) || die "--enable-dns-support requires a value"
      dns_support="$(normalize_bool "$1")"
      ;;
    --enable-dns-hostnames)
      shift
      (($#)) || die "--enable-dns-hostnames requires a value"
      dns_hostnames="$(normalize_bool "$1")"
      ;;
    --tag)
      shift
      (($#)) || die "--tag requires a value"
      validate_tag_pair "$1" || die "invalid --tag format (expected KEY=VALUE): $1"
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

[[ -n "$cidr_block" ]] || die "--cidr is required"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

existing_vpc_id="$(find_existing_vpc)"
if [[ "$existing_vpc_id" != "None" && -n "$existing_vpc_id" ]]; then
  if $if_not_exists; then
    log "found existing VPC: $existing_vpc_id"
    printf '%s\n' "$existing_vpc_id"
    exit 0
  fi
  die "matching VPC already exists: $existing_vpc_id"
fi

if $dry_run; then
  run_cmd aws "${aws_options[@]}" ec2 create-vpc --cidr-block "$cidr_block" --instance-tenancy "$tenancy"
  if [[ -n "$vpc_name" || ${#tag_pairs[@]} -gt 0 ]]; then
    run_cmd aws "${aws_options[@]}" ec2 create-tags --resources vpc-DRYRUN --tags Key=Name,Value="$vpc_name"
  fi
  run_cmd aws "${aws_options[@]}" ec2 modify-vpc-attribute --vpc-id vpc-DRYRUN --enable-dns-support "Value=$dns_support"
  run_cmd aws "${aws_options[@]}" ec2 modify-vpc-attribute --vpc-id vpc-DRYRUN --enable-dns-hostnames "Value=$dns_hostnames"
  printf '%s\n' "vpc-DRYRUN"
  exit 0
fi

vpc_id="$(aws "${aws_options[@]}" ec2 create-vpc --cidr-block "$cidr_block" --instance-tenancy "$tenancy" --query 'Vpc.VpcId' --output text)"
[[ -n "$vpc_id" && "$vpc_id" != "None" ]] || die "failed to create VPC"
log "created VPC: $vpc_id"

if [[ -n "$vpc_name" || ${#tag_pairs[@]} -gt 0 ]]; then
  tag_args=()
  [[ -n "$vpc_name" ]] && tag_args+=("Key=Name,Value=${vpc_name}")
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    tag_args+=("Key=${tag_key},Value=${tag_value}")
  done
  run_cmd aws "${aws_options[@]}" ec2 create-tags --resources "$vpc_id" --tags "${tag_args[@]}"
fi

run_cmd aws "${aws_options[@]}" ec2 modify-vpc-attribute --vpc-id "$vpc_id" --enable-dns-support "Value=$dns_support"
run_cmd aws "${aws_options[@]}" ec2 modify-vpc-attribute --vpc-id "$vpc_id" --enable-dns-hostnames "Value=$dns_hostnames"

if $wait_enabled; then
  wait_for_vpc_available
fi

printf '%s\n' "$vpc_id"
exit 0
