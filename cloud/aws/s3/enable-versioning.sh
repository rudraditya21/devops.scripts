#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: enable-versioning.sh [OPTIONS]

Enable or suspend S3 bucket versioning.

Options:
  --bucket NAME        Bucket name (required)
  --status STATUS      Enabled|Suspended (default: Enabled)
  --region REGION      AWS region override
  --profile PROFILE    AWS CLI profile
  --wait               Wait until status reflects requested value (default)
  --no-wait            Return after API call
  --timeout SEC        Wait timeout in seconds (default: 120)
  --poll-interval SEC  Wait polling interval in seconds (default: 5)
  --dry-run            Print planned commands only
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [enable-versioning] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_bucket_name() {
  local name="$1"
  [[ ${#name} -ge 3 && ${#name} -le 63 ]] || return 1
  [[ "$name" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]] || return 1
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

wait_for_status() {
  local start_time elapsed current_status
  start_time="$(date +%s)"

  while true; do
    current_status="$(aws "${aws_options[@]}" s3api get-bucket-versioning --bucket "$bucket_name" --query 'Status' --output text 2> /dev/null || true)"
    [[ "$current_status" == "None" ]] && current_status="Suspended"

    if [[ "$current_status" == "$requested_status" ]]; then
      return 0
    fi

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for versioning status '$requested_status'"
    fi

    sleep "$poll_interval"
  done
}

bucket_name=""
requested_status="Enabled"
region=""
profile=""
wait_enabled=true
timeout_seconds=120
poll_interval=5
dry_run=false

while (($#)); do
  case "$1" in
    --bucket)
      shift
      (($#)) || die "--bucket requires a value"
      validate_bucket_name "$1" || die "invalid bucket name: $1"
      bucket_name="$1"
      ;;
    --status)
      shift
      (($#)) || die "--status requires a value"
      case "$1" in
        Enabled | Suspended) requested_status="$1" ;;
        *) die "invalid --status value: $1 (expected Enabled|Suspended)" ;;
      esac
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

[[ -n "$bucket_name" ]] || die "--bucket is required"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

run_cmd aws "${aws_options[@]}" s3api put-bucket-versioning --bucket "$bucket_name" --versioning-configuration "Status=$requested_status"
log "versioning request submitted: $requested_status"

if $wait_enabled && ! $dry_run; then
  wait_for_status
  log "versioning status confirmed: $requested_status"
fi

exit 0
