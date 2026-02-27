#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: snapshot-restore.sh [OPTIONS]

Restore an AWS RDS DB instance from a manual snapshot.

Options:
  --snapshot-id ID              Source DB snapshot identifier (required)
  --identifier ID               Target DB instance identifier (required)
  --instance-class CLASS        Target DB instance class
  --port PORT                   Database port
  --availability-zone AZ        Preferred availability zone
  --db-subnet-group NAME        DB subnet group name
  --vpc-security-group-id SG    VPC security group ID (repeatable)
  --vpc-security-group-ids CSV  Comma-separated VPC security group IDs
  --storage-type TYPE           Storage type override (gp2|gp3|io1|io2|standard)
  --multi-az                    Enable Multi-AZ restore
  --no-multi-az                 Disable Multi-AZ restore
  --publicly-accessible         Enable public accessibility
  --no-publicly-accessible      Disable public accessibility
  --copy-tags-to-snapshot       Copy instance tags to future snapshots (default)
  --no-copy-tags-to-snapshot    Disable copy-tags-to-snapshot
  --deletion-protection         Enable deletion protection (default)
  --no-deletion-protection      Disable deletion protection
  --wait                        Wait until restored instance is available
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
  printf '%s [snapshot-restore] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

validate_instance_class() {
  [[ "$1" =~ ^db\.[a-z0-9.-]+$ ]]
}

validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (("$1" >= 1 && "$1" <= 65535))
}

validate_storage_type() {
  [[ "$1" =~ ^(gp2|gp3|io1|io2|standard)$ ]]
}

wait_for_instance_available() {
  local start_time elapsed status
  start_time="$(date +%s)"

  while true; do
    status="$(aws "${aws_options[@]}" rds describe-db-instances \
      --db-instance-identifier "$identifier" \
      --query 'DBInstances[0].DBInstanceStatus' \
      --output text 2> /dev/null || true)"

    case "$status" in
      available) return 0 ;;
      failed | incompatible-restore | incompatible-network) die "instance entered terminal status: $status" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for restored instance to become available: $identifier"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
snapshot_id=""
identifier=""
instance_class=""
port=""
availability_zone=""
db_subnet_group=""
vpc_security_group_ids=()
storage_type=""
multi_az_mode="unset"
publicly_accessible_mode="unset"
copy_tags_to_snapshot=true
deletion_protection=true
wait_enabled=false
timeout_seconds=7200
poll_interval=20
dry_run=false

while (($#)); do
  case "$1" in
    --snapshot-id)
      shift
      (($#)) || die "--snapshot-id requires a value"
      validate_snapshot_identifier "$1" || die "invalid --snapshot-id value"
      snapshot_id="$1"
      ;;
    --identifier)
      shift
      (($#)) || die "--identifier requires a value"
      validate_identifier "$1" || die "invalid --identifier value"
      identifier="$1"
      ;;
    --instance-class)
      shift
      (($#)) || die "--instance-class requires a value"
      validate_instance_class "$1" || die "invalid --instance-class format"
      instance_class="$1"
      ;;
    --port)
      shift
      (($#)) || die "--port requires a value"
      validate_port "$1" || die "--port must be between 1 and 65535"
      port="$1"
      ;;
    --availability-zone)
      shift
      (($#)) || die "--availability-zone requires a value"
      availability_zone="$1"
      ;;
    --db-subnet-group)
      shift
      (($#)) || die "--db-subnet-group requires a value"
      db_subnet_group="$1"
      ;;
    --vpc-security-group-id)
      shift
      (($#)) || die "--vpc-security-group-id requires a value"
      vpc_security_group_ids+=("$1")
      ;;
    --vpc-security-group-ids)
      shift
      (($#)) || die "--vpc-security-group-ids requires a value"
      IFS=',' read -r -a parsed_sg_ids <<< "$1"
      for sg in "${parsed_sg_ids[@]}"; do
        sg="$(trim_spaces "$sg")"
        [[ -n "$sg" ]] || continue
        vpc_security_group_ids+=("$sg")
      done
      ;;
    --storage-type)
      shift
      (($#)) || die "--storage-type requires a value"
      validate_storage_type "$1" || die "invalid --storage-type value"
      storage_type="$1"
      ;;
    --multi-az)
      multi_az_mode="true"
      ;;
    --no-multi-az)
      multi_az_mode="false"
      ;;
    --publicly-accessible)
      publicly_accessible_mode="true"
      ;;
    --no-publicly-accessible)
      publicly_accessible_mode="false"
      ;;
    --copy-tags-to-snapshot)
      copy_tags_to_snapshot=true
      ;;
    --no-copy-tags-to-snapshot)
      copy_tags_to_snapshot=false
      ;;
    --deletion-protection)
      deletion_protection=true
      ;;
    --no-deletion-protection)
      deletion_protection=false
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
[[ -n "$snapshot_id" ]] || die "--snapshot-id is required"
[[ -n "$identifier" ]] || die "--identifier is required"

snapshot_status="$(aws "${aws_options[@]}" rds describe-db-snapshots \
  --db-snapshot-identifier "$snapshot_id" \
  --query 'DBSnapshots[0].Status' \
  --output text 2> /dev/null || true)"

[[ -n "$snapshot_status" && "$snapshot_status" != "None" ]] || die "snapshot not found: $snapshot_id"
[[ "$snapshot_status" == "available" ]] || die "snapshot is not in available state: $snapshot_status"

existing="$(aws "${aws_options[@]}" rds describe-db-instances \
  --db-instance-identifier "$identifier" \
  --query 'DBInstances[0].DBInstanceIdentifier' \
  --output text 2> /dev/null || true)"

if [[ -n "$existing" && "$existing" != "None" ]]; then
  die "target DB instance already exists: $identifier"
fi

restore_cmd=(
  aws "${aws_options[@]}" rds restore-db-instance-from-db-snapshot
  --db-instance-identifier "$identifier"
  --db-snapshot-identifier "$snapshot_id"
)

[[ -n "$instance_class" ]] && restore_cmd+=(--db-instance-class "$instance_class")
[[ -n "$port" ]] && restore_cmd+=(--port "$port")
[[ -n "$availability_zone" ]] && restore_cmd+=(--availability-zone "$availability_zone")
[[ -n "$db_subnet_group" ]] && restore_cmd+=(--db-subnet-group-name "$db_subnet_group")
[[ -n "$storage_type" ]] && restore_cmd+=(--storage-type "$storage_type")

if ((${#vpc_security_group_ids[@]} > 0)); then
  restore_cmd+=(--vpc-security-group-ids "${vpc_security_group_ids[@]}")
fi

case "$multi_az_mode" in
  true) restore_cmd+=(--multi-az) ;;
  false) restore_cmd+=(--no-multi-az) ;;
esac

case "$publicly_accessible_mode" in
  true) restore_cmd+=(--publicly-accessible) ;;
  false) restore_cmd+=(--no-publicly-accessible) ;;
esac

if $copy_tags_to_snapshot; then
  restore_cmd+=(--copy-tags-to-snapshot)
else
  restore_cmd+=(--no-copy-tags-to-snapshot)
fi

if $deletion_protection; then
  restore_cmd+=(--deletion-protection)
else
  restore_cmd+=(--no-deletion-protection)
fi

if $dry_run; then
  printf 'DRY-RUN:' >&2
  printf ' %q' "${restore_cmd[@]}" >&2
  printf '\n' >&2
  log "dry-run mode: instance not restored"
  exit 0
fi

restored_id="$("${restore_cmd[@]}" --query 'DBInstance.DBInstanceIdentifier' --output text)"
[[ -n "$restored_id" && "$restored_id" != "None" ]] || die "failed to obtain restored DBInstanceIdentifier"
log "restore requested for DB instance: $restored_id"

if $wait_enabled; then
  wait_for_instance_available
  log "restored instance is available: $restored_id"
fi

printf '%s\n' "$restored_id"
exit 0
