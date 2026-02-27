#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: list-instances.sh [OPTIONS]

List EC2 instances with flexible filtering and output modes.

Options:
  --region REGION      AWS region (optional, falls back to AWS config)
  --profile PROFILE    AWS CLI profile
  --state CSV          Instance states filter (default: pending,running,stopping,stopped,shutting-down)
  --tag KEY=VALUE      Tag filter (repeatable)
  --id INSTANCE_ID     Instance ID filter (repeatable)
  --ids CSV            Comma-separated instance IDs
  --output MODE        table|json|ids (default: table)
  --include-terminated Include terminated instances in default listing
  --dry-run            Print AWS command only
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_instance_id() {
  [[ "$1" =~ ^i-[a-f0-9]{8,17}$ ]]
}

validate_tag_filter() {
  [[ "$1" =~ ^[^=]+=[^=].*$ ]]
}

aws_options=()
state_csv="pending,running,stopping,stopped,shutting-down"
output_mode="table"
include_terminated=false
dry_run=false
id_filters=()
tag_filters=()

while (($#)); do
  case "$1" in
    --region)
      shift
      (($#)) || die "--region requires a value"
      aws_options+=(--region "$1")
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      aws_options+=(--profile "$1")
      ;;
    --state)
      shift
      (($#)) || die "--state requires a value"
      state_csv="$1"
      ;;
    --tag)
      shift
      (($#)) || die "--tag requires a value"
      validate_tag_filter "$1" || die "invalid --tag format (expected KEY=VALUE): $1"
      tag_filters+=("$1")
      ;;
    --id)
      shift
      (($#)) || die "--id requires a value"
      validate_instance_id "$1" || die "invalid instance ID: $1"
      id_filters+=("$1")
      ;;
    --ids)
      shift
      (($#)) || die "--ids requires a value"
      IFS=',' read -r -a parsed_ids <<< "$1"
      for id in "${parsed_ids[@]}"; do
        id="$(trim_spaces "$id")"
        [[ -n "$id" ]] || continue
        validate_instance_id "$id" || die "invalid instance ID in --ids: $id"
        id_filters+=("$id")
      done
      ;;
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        table | json | ids) output_mode="$1" ;;
        *) die "invalid --output value: $1 (expected table|json|ids)" ;;
      esac
      ;;
    --include-terminated)
      include_terminated=true
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

command_exists aws || die "aws CLI is required but not found"

filters=()
if [[ -n "$state_csv" ]]; then
  if ! $include_terminated || [[ "$state_csv" != "" ]]; then
    filters+=("Name=instance-state-name,Values=${state_csv}")
  fi
fi

if $include_terminated && [[ "$state_csv" == "pending,running,stopping,stopped,shutting-down" ]]; then
  filters=()
fi

for tag_filter in "${tag_filters[@]}"; do
  tag_key="${tag_filter%%=*}"
  tag_value="${tag_filter#*=}"
  filters+=("Name=tag:${tag_key},Values=${tag_value}")
done

base_cmd=(aws "${aws_options[@]}" ec2 describe-instances)
if ((${#id_filters[@]} > 0)); then
  base_cmd+=(--instance-ids "${id_filters[@]}")
fi
if ((${#filters[@]} > 0)); then
  base_cmd+=(--filters "${filters[@]}")
fi

if $dry_run; then
  printf 'DRY-RUN:' >&2
  printf ' %q' "${base_cmd[@]}"
  printf '\n' >&2
  exit 0
fi

case "$output_mode" in
  table)
    # shellcheck disable=SC2016
    "${base_cmd[@]}" \
      --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,InstanceType:InstanceType,AZ:Placement.AvailabilityZone,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}' \
      --output table
    ;;
  json)
    # shellcheck disable=SC2016
    "${base_cmd[@]}" \
      --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,InstanceType:InstanceType,AZ:Placement.AvailabilityZone,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,LaunchTime:LaunchTime}' \
      --output json
    ;;
  ids)
    "${base_cmd[@]}" \
      --query 'Reservations[].Instances[].InstanceId' \
      --output text
    ;;
esac

exit 0
