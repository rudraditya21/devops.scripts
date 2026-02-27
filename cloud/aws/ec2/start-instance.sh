#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: start-instance.sh [OPTIONS]

Start one or more EC2 instances safely with optional wait.

Options:
  --id INSTANCE_ID     Instance ID (repeatable)
  --ids CSV            Comma-separated instance IDs
  --region REGION      AWS region
  --profile PROFILE    AWS CLI profile
  --wait               Wait until all target instances are running (default)
  --no-wait            Return immediately after API call
  --timeout SEC        Wait timeout in seconds (default: 900)
  --poll-interval SEC  Poll interval in seconds (default: 10)
  --dry-run            Print actions without executing
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [start-instance] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

wait_for_running() {
  local start_time elapsed pending_count instance_state instance_id
  start_time="$(date +%s)"

  while true; do
    pending_count=0

    while read -r instance_id instance_state; do
      [[ -n "$instance_id" ]] || continue
      case "$instance_state" in
        running) ;;
        *)
          pending_count=$((pending_count + 1))
          ;;
      esac
    done < <(aws "${aws_options[@]}" ec2 describe-instances \
      --instance-ids "${instance_ids[@]}" \
      --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
      --output text)

    if ((pending_count == 0)); then
      log "all instances reached running state"
      return 0
    fi

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for instances to reach running state"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
instance_ids=()
wait_enabled=true
timeout_seconds=900
poll_interval=10
dry_run=false

while (($#)); do
  case "$1" in
    --id)
      shift
      (($#)) || die "--id requires a value"
      validate_instance_id "$1" || die "invalid instance ID: $1"
      instance_ids+=("$1")
      ;;
    --ids)
      shift
      (($#)) || die "--ids requires a value"
      IFS=',' read -r -a parsed_ids <<< "$1"
      for id in "${parsed_ids[@]}"; do
        id="$(trim_spaces "$id")"
        [[ -n "$id" ]] || continue
        validate_instance_id "$id" || die "invalid instance ID in --ids: $id"
        instance_ids+=("$id")
      done
      ;;
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
      poll_interval="$1"
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
((${#instance_ids[@]} > 0)) || die "at least one instance ID is required (--id/--ids)"

start_targets=()
while read -r instance_id instance_state; do
  [[ -n "$instance_id" ]] || continue
  case "$instance_state" in
    running | pending)
      log "skipping $instance_id (state: $instance_state)"
      ;;
    stopped | stopping)
      start_targets+=("$instance_id")
      ;;
    *)
      die "instance $instance_id is in unsupported state for start: $instance_state"
      ;;
  esac
done < <(aws "${aws_options[@]}" ec2 describe-instances \
  --instance-ids "${instance_ids[@]}" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output text)

if ((${#start_targets[@]} == 0)); then
  log "no instances require start"
  exit 0
fi

run_cmd aws "${aws_options[@]}" ec2 start-instances --instance-ids "${start_targets[@]}" > /dev/null
log "start requested for: ${start_targets[*]}"

if $wait_enabled; then
  if $dry_run; then
    log "dry-run mode: skipping wait loop"
  else
    wait_for_running
  fi
fi

exit 0
