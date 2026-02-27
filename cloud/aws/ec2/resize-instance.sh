#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: resize-instance.sh [OPTIONS]

Resize an EC2 instance type with safe stop/modify/start workflow.

Options:
  --id INSTANCE_ID       Instance ID to resize (required)
  --instance-type TYPE   Target instance type (required)
  --region REGION        AWS region
  --profile PROFILE      AWS CLI profile
  --allow-stop           Allow script to stop running instance
  --start-after          Start instance after resize
  --no-start-after       Keep instance stopped after resize
  --wait                 Wait for state transitions (default)
  --no-wait              Do not wait for state transitions
  --timeout SEC          Wait timeout in seconds (default: 1200)
  --poll-interval SEC    Poll interval in seconds (default: 15)
  --dry-run              Print actions without executing
  -h, --help             Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [resize-instance] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_instance_id() {
  [[ "$1" =~ ^i-[a-f0-9]{8,17}$ ]]
}

validate_instance_type() {
  [[ "$1" =~ ^[a-z0-9]+[.][a-z0-9]+$ ]]
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

wait_for_state() {
  local target_state="$1"
  local start_time elapsed current_state
  start_time="$(date +%s)"

  while true; do
    current_state="$(aws "${aws_options[@]}" ec2 describe-instances \
      --instance-ids "$instance_id" \
      --query 'Reservations[0].Instances[0].State.Name' \
      --output text)"

    [[ "$current_state" == "$target_state" ]] && return 0

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for $instance_id to reach state '$target_state'"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
instance_id=""
target_type=""
allow_stop=false
start_after_mode="auto"
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
      instance_id="$1"
      ;;
    --instance-type)
      shift
      (($#)) || die "--instance-type requires a value"
      validate_instance_type "$1" || die "invalid instance type format: $1"
      target_type="$1"
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
    --allow-stop)
      allow_stop=true
      ;;
    --start-after)
      start_after_mode="true"
      ;;
    --no-start-after)
      start_after_mode="false"
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
[[ -n "$instance_id" ]] || die "--id is required"
[[ -n "$target_type" ]] || die "--instance-type is required"

instance_state="$(aws "${aws_options[@]}" ec2 describe-instances \
  --instance-ids "$instance_id" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)"

current_type="$(aws "${aws_options[@]}" ec2 describe-instances \
  --instance-ids "$instance_id" \
  --query 'Reservations[0].Instances[0].InstanceType' \
  --output text)"

case "$instance_state" in
  terminated | shutting-down)
    die "instance $instance_id is in non-resizable state: $instance_state"
    ;;
esac

was_running=false
case "$instance_state" in
  running | pending)
    was_running=true
    ;;
esac

if [[ "$current_type" == "$target_type" ]]; then
  log "instance already has target type: $target_type"
  exit 0
fi

if $was_running; then
  if ! $allow_stop; then
    die "instance is running; pass --allow-stop to permit stop/start workflow"
  fi
  run_cmd aws "${aws_options[@]}" ec2 stop-instances --instance-ids "$instance_id" > /dev/null
  log "stop requested for $instance_id"
  if $wait_enabled && ! $dry_run; then
    wait_for_state stopped
  fi
fi

if [[ "$instance_state" == "stopping" ]] && $wait_enabled && ! $dry_run; then
  wait_for_state stopped
fi

run_cmd aws "${aws_options[@]}" ec2 modify-instance-attribute \
  --instance-id "$instance_id" \
  --instance-type "Value=$target_type"
log "resize requested: $instance_id -> $target_type"

start_after=false
case "$start_after_mode" in
  auto)
    $was_running && start_after=true
    ;;
  true)
    start_after=true
    ;;
  false)
    start_after=false
    ;;
esac

if $start_after; then
  run_cmd aws "${aws_options[@]}" ec2 start-instances --instance-ids "$instance_id" > /dev/null
  log "start requested for $instance_id"
  if $wait_enabled && ! $dry_run; then
    wait_for_state running
  fi
fi

exit 0
