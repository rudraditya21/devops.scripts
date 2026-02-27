#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: delete-instance.sh [OPTIONS]

Delete an AWS RDS DB instance with controlled snapshot behavior.

Options:
  --identifier ID               DB instance identifier (required)
  --skip-final-snapshot         Skip final snapshot (dangerous)
  --final-snapshot-id ID        Final snapshot identifier (auto-generated when omitted)
  --delete-automated-backups    Delete retained automated backups (default)
  --retain-automated-backups    Keep retained automated backups
  --wait                        Wait until DB instance is fully deleted
  --timeout SEC                 Wait timeout in seconds (default: 7200)
  --poll-interval SEC           Poll interval in seconds (default: 20)
  --region REGION               AWS region
  --profile PROFILE             AWS CLI profile
  --dry-run                     Print AWS command without executing
  -h, --help                    Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [delete-instance] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_identifier() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ && ! "$1" =~ -- && ! "$1" =~ -$ ]]
}

validate_snapshot_identifier() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,254}$ && ! "$1" =~ -- && ! "$1" =~ -$ ]]
}

timestamp_utc() {
  date -u +"%Y%m%d%H%M%S"
}

wait_for_deleted() {
  local start_time elapsed out rc
  start_time="$(date +%s)"

  while true; do
    set +e
    out="$(aws "${aws_options[@]}" rds describe-db-instances \
      --db-instance-identifier "$identifier" \
      --query 'DBInstances[0].DBInstanceStatus' \
      --output text 2>&1)"
    rc=$?
    set -e

    if ((rc != 0)); then
      if grep -q "DBInstanceNotFound" <<< "$out"; then
        return 0
      fi
      die "failed while checking deletion status: $out"
    fi

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for DB instance deletion: $identifier"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
identifier=""
skip_final_snapshot=false
final_snapshot_id=""
delete_automated_backups=true
wait_enabled=false
timeout_seconds=7200
poll_interval=20
dry_run=false

while (($#)); do
  case "$1" in
    --identifier)
      shift
      (($#)) || die "--identifier requires a value"
      validate_identifier "$1" || die "invalid --identifier value"
      identifier="$1"
      ;;
    --skip-final-snapshot)
      skip_final_snapshot=true
      ;;
    --final-snapshot-id)
      shift
      (($#)) || die "--final-snapshot-id requires a value"
      validate_snapshot_identifier "$1" || die "invalid --final-snapshot-id value"
      final_snapshot_id="$1"
      ;;
    --delete-automated-backups)
      delete_automated_backups=true
      ;;
    --retain-automated-backups)
      delete_automated_backups=false
      ;;
    --wait)
      wait_enabled=true
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
[[ -n "$identifier" ]] || die "--identifier is required"

instance_state="$(aws "${aws_options[@]}" rds describe-db-instances \
  --db-instance-identifier "$identifier" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2> /dev/null || true)"

if [[ -z "$instance_state" || "$instance_state" == "None" ]]; then
  die "DB instance not found: $identifier"
fi

if [[ "$instance_state" == "deleting" ]]; then
  log "instance is already deleting: $identifier"
  if $wait_enabled; then
    wait_for_deleted
    log "instance deleted: $identifier"
  fi
  exit 0
fi

if $skip_final_snapshot && [[ -n "$final_snapshot_id" ]]; then
  die "--final-snapshot-id cannot be used with --skip-final-snapshot"
fi

if ! $skip_final_snapshot && [[ -z "$final_snapshot_id" ]]; then
  final_snapshot_id="${identifier}-final-$(timestamp_utc)"
fi

delete_cmd=(aws "${aws_options[@]}" rds delete-db-instance --db-instance-identifier "$identifier")

if $skip_final_snapshot; then
  delete_cmd+=(--skip-final-snapshot)
else
  validate_snapshot_identifier "$final_snapshot_id" || die "generated final snapshot ID is invalid: $final_snapshot_id"
  delete_cmd+=(--final-db-snapshot-identifier "$final_snapshot_id")
fi

if $delete_automated_backups; then
  delete_cmd+=(--delete-automated-backups)
else
  delete_cmd+=(--no-delete-automated-backups)
fi

if $dry_run; then
  printf 'DRY-RUN:' >&2
  printf ' %q' "${delete_cmd[@]}" >&2
  printf '\n' >&2
  log "dry-run mode: instance not deleted"
  exit 0
fi

"${delete_cmd[@]}" > /dev/null
log "delete requested for DB instance: $identifier"
if ! $skip_final_snapshot; then
  log "final snapshot: $final_snapshot_id"
fi

if $wait_enabled; then
  wait_for_deleted
  log "instance deleted: $identifier"
fi

exit 0
