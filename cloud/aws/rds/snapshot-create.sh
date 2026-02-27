#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: snapshot-create.sh [OPTIONS]

Create a manual snapshot for an AWS RDS DB instance.

Options:
  --identifier ID              DB instance identifier (required)
  --snapshot-id ID             Snapshot identifier (auto-generated when omitted)
  --tag KEY=VALUE              Snapshot tag pair (repeatable)
  --tags CSV                   Comma-separated snapshot tags
  --wait                       Wait until snapshot is available
  --timeout SEC                Wait timeout in seconds (default: 7200)
  --poll-interval SEC          Poll interval in seconds (default: 20)
  --region REGION              AWS region
  --profile PROFILE            AWS CLI profile
  --dry-run                    Print AWS command without executing
  -h, --help                   Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [snapshot-create] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_identifier() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ && ! "$1" =~ -- && ! "$1" =~ -$ ]]
}

validate_snapshot_identifier() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,254}$ && ! "$1" =~ -- && ! "$1" =~ -$ ]]
}

validate_tag_pair() {
  [[ "$1" =~ ^[^=]+=[^=].*$ ]]
}

parse_tag_pair() {
  local pair="$1"
  tag_key="${pair%%=*}"
  tag_value="${pair#*=}"
}

timestamp_utc() {
  date -u +"%Y%m%d%H%M%S"
}

wait_for_snapshot_available() {
  local start_time elapsed status
  start_time="$(date +%s)"

  while true; do
    status="$(aws "${aws_options[@]}" rds describe-db-snapshots \
      --db-snapshot-identifier "$snapshot_id" \
      --query 'DBSnapshots[0].Status' \
      --output text 2> /dev/null || true)"

    case "$status" in
      available) return 0 ;;
      failed | deleted) die "snapshot entered terminal state: $status" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for snapshot to become available: $snapshot_id"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
identifier=""
snapshot_id=""
tag_pairs=()
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
    --snapshot-id)
      shift
      (($#)) || die "--snapshot-id requires a value"
      validate_snapshot_identifier "$1" || die "invalid --snapshot-id value"
      snapshot_id="$1"
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

if [[ -z "$snapshot_id" ]]; then
  snapshot_id="${identifier}-manual-$(timestamp_utc)"
fi
validate_snapshot_identifier "$snapshot_id" || die "invalid --snapshot-id value"

instance_state="$(aws "${aws_options[@]}" rds describe-db-instances \
  --db-instance-identifier "$identifier" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2> /dev/null || true)"
[[ -n "$instance_state" && "$instance_state" != "None" ]] || die "DB instance not found: $identifier"

existing_snapshot="$(aws "${aws_options[@]}" rds describe-db-snapshots \
  --db-snapshot-identifier "$snapshot_id" \
  --query 'DBSnapshots[0].DBSnapshotIdentifier' \
  --output text 2> /dev/null || true)"

if [[ -n "$existing_snapshot" && "$existing_snapshot" != "None" ]]; then
  die "snapshot already exists: $snapshot_id"
fi

create_cmd=(
  aws "${aws_options[@]}" rds create-db-snapshot
  --db-instance-identifier "$identifier"
  --db-snapshot-identifier "$snapshot_id"
)

if ((${#tag_pairs[@]} > 0)); then
  tag_args=()
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    tag_args+=("Key=${tag_key},Value=${tag_value}")
  done
  create_cmd+=(--tags "${tag_args[@]}")
fi

if $dry_run; then
  printf 'DRY-RUN:' >&2
  printf ' %q' "${create_cmd[@]}" >&2
  printf '\n' >&2
  log "dry-run mode: snapshot not created"
  exit 0
fi

created_snapshot_id="$("${create_cmd[@]}" --query 'DBSnapshot.DBSnapshotIdentifier' --output text)"
[[ -n "$created_snapshot_id" && "$created_snapshot_id" != "None" ]] || die "failed to obtain DBSnapshotIdentifier"
log "snapshot create requested: $created_snapshot_id"

if $wait_enabled; then
  wait_for_snapshot_available
  log "snapshot is available: $created_snapshot_id"
fi

printf '%s\n' "$created_snapshot_id"
exit 0
