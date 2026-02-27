#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: reboot-instance.sh [OPTIONS]

Reboot one or more running EC2 instances and optionally wait for health.

Options:
  --id INSTANCE_ID     Instance ID (repeatable)
  --ids CSV            Comma-separated instance IDs
  --region REGION      AWS region
  --profile PROFILE    AWS CLI profile
  --wait               Wait until status checks pass (default)
  --no-wait            Return immediately after API call
  --timeout SEC        Wait timeout in seconds (default: 1200)
  --poll-interval SEC  Poll interval in seconds (default: 15)
  --dry-run            Print actions without executing
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [reboot-instance] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

wait_for_status_ok() {
  local start_time elapsed id status_line instance_status system_status
  start_time="$(date +%s)"

  while true; do
    all_ready=true

    for id in "${instance_ids[@]}"; do
      status_line="$(aws "${aws_options[@]}" ec2 describe-instance-status \
        --include-all-instances \
        --instance-ids "$id" \
        --query 'InstanceStatuses[0].[InstanceStatus.Status,SystemStatus.Status]' \
        --output text)"

      if [[ -z "$status_line" || "$status_line" == "None None" ]]; then
        all_ready=false
        continue
      fi

      read -r instance_status system_status <<< "$status_line"
      if [[ "$instance_status" != "ok" || "$system_status" != "ok" ]]; then
        all_ready=false
      fi
    done

    if $all_ready; then
      log "all instances passed status checks"
      return 0
    fi

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for instance status checks"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
instance_ids=()
wait_enabled=true
timeout_seconds=1200
poll_interval=15
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

while read -r instance_id instance_state; do
  [[ -n "$instance_id" ]] || continue
  case "$instance_state" in
    running) ;;
    *) die "instance $instance_id must be running to reboot (current state: $instance_state)" ;;
  esac
done < <(aws "${aws_options[@]}" ec2 describe-instances \
  --instance-ids "${instance_ids[@]}" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output text)

run_cmd aws "${aws_options[@]}" ec2 reboot-instances --instance-ids "${instance_ids[@]}"
log "reboot requested for: ${instance_ids[*]}"

if $wait_enabled; then
  if $dry_run; then
    log "dry-run mode: skipping wait loop"
  else
    wait_for_status_ok
  fi
fi

exit 0
