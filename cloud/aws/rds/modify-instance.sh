#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: modify-instance.sh [OPTIONS]

Modify mutable configuration of an existing AWS RDS DB instance.

Options:
  --identifier ID                  DB instance identifier (required)
  --instance-class CLASS           New DB instance class
  --allocated-storage GB           New allocated storage in GiB
  --storage-type TYPE              Storage type (gp2|gp3|io1|io2|standard)
  --iops N                         Provisioned IOPS
  --backup-retention-days N        Backup retention days (0-35)
  --maintenance-window WINDOW      Preferred maintenance window (ddd:hh24:mi-ddd:hh24:mi)
  --backup-window WINDOW           Preferred backup window (hh24:mi-hh24:mi)
  --ca-certificate-id ID           CA certificate identifier
  --multi-az                       Enable Multi-AZ
  --no-multi-az                    Disable Multi-AZ
  --auto-minor-version-upgrade     Enable auto minor version upgrades
  --no-auto-minor-version-upgrade  Disable auto minor version upgrades
  --deletion-protection            Enable deletion protection
  --no-deletion-protection         Disable deletion protection
  --apply-immediately              Apply changes immediately
  --wait                           Wait until instance returns to available
  --timeout SEC                    Wait timeout in seconds (default: 7200)
  --poll-interval SEC              Poll interval in seconds (default: 20)
  --region REGION                  AWS region
  --profile PROFILE                AWS CLI profile
  --dry-run                        Print AWS command without executing
  -h, --help                       Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [modify-instance] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_identifier() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ && ! "$1" =~ -- && ! "$1" =~ -$ ]]
}

validate_instance_class() {
  [[ "$1" =~ ^db\.[a-z0-9.-]+$ ]]
}

validate_storage_type() {
  [[ "$1" =~ ^(gp2|gp3|io1|io2|standard)$ ]]
}

validate_maintenance_window() {
  [[ "$1" =~ ^[a-z]{3}:[0-2][0-9]:[0-5][0-9]-[a-z]{3}:[0-2][0-9]:[0-5][0-9]$ ]]
}

validate_backup_window() {
  [[ "$1" =~ ^[0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$ ]]
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
      die "timeout waiting for DB instance to become available: $identifier"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
identifier=""
instance_class=""
allocated_storage=""
storage_type=""
iops=""
backup_retention_days=""
maintenance_window=""
backup_window=""
ca_certificate_id=""
multi_az_mode="unset"
auto_minor_upgrade_mode="unset"
deletion_protection_mode="unset"
apply_immediately=false
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
    --instance-class)
      shift
      (($#)) || die "--instance-class requires a value"
      validate_instance_class "$1" || die "invalid --instance-class format"
      instance_class="$1"
      ;;
    --allocated-storage)
      shift
      (($#)) || die "--allocated-storage requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--allocated-storage must be a positive integer"
      allocated_storage="$1"
      ;;
    --storage-type)
      shift
      (($#)) || die "--storage-type requires a value"
      validate_storage_type "$1" || die "invalid --storage-type value"
      storage_type="$1"
      ;;
    --iops)
      shift
      (($#)) || die "--iops requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--iops must be a positive integer"
      iops="$1"
      ;;
    --backup-retention-days)
      shift
      (($#)) || die "--backup-retention-days requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--backup-retention-days must be an integer"
      (("$1" >= 0 && "$1" <= 35)) || die "--backup-retention-days must be between 0 and 35"
      backup_retention_days="$1"
      ;;
    --maintenance-window)
      shift
      (($#)) || die "--maintenance-window requires a value"
      validate_maintenance_window "$1" || die "invalid --maintenance-window format"
      maintenance_window="$1"
      ;;
    --backup-window)
      shift
      (($#)) || die "--backup-window requires a value"
      validate_backup_window "$1" || die "invalid --backup-window format"
      backup_window="$1"
      ;;
    --ca-certificate-id)
      shift
      (($#)) || die "--ca-certificate-id requires a value"
      ca_certificate_id="$1"
      ;;
    --multi-az)
      multi_az_mode="true"
      ;;
    --no-multi-az)
      multi_az_mode="false"
      ;;
    --auto-minor-version-upgrade)
      auto_minor_upgrade_mode="true"
      ;;
    --no-auto-minor-version-upgrade)
      auto_minor_upgrade_mode="false"
      ;;
    --deletion-protection)
      deletion_protection_mode="true"
      ;;
    --no-deletion-protection)
      deletion_protection_mode="false"
      ;;
    --apply-immediately)
      apply_immediately=true
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

if [[ -z "$instance_class" && -z "$allocated_storage" && -z "$storage_type" && -z "$iops" && -z "$backup_retention_days" && -z "$maintenance_window" && -z "$backup_window" && -z "$ca_certificate_id" && "$multi_az_mode" == "unset" && "$auto_minor_upgrade_mode" == "unset" && "$deletion_protection_mode" == "unset" ]]; then
  die "no modifications specified"
fi

instance_state="$(aws "${aws_options[@]}" rds describe-db-instances \
  --db-instance-identifier "$identifier" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2> /dev/null || true)"

[[ -n "$instance_state" && "$instance_state" != "None" ]] || die "DB instance not found: $identifier"

if [[ "$instance_state" == "deleting" ]]; then
  die "cannot modify instance while deleting"
fi

modify_cmd=(aws "${aws_options[@]}" rds modify-db-instance --db-instance-identifier "$identifier")

[[ -n "$instance_class" ]] && modify_cmd+=(--db-instance-class "$instance_class")
[[ -n "$allocated_storage" ]] && modify_cmd+=(--allocated-storage "$allocated_storage")
[[ -n "$storage_type" ]] && modify_cmd+=(--storage-type "$storage_type")
[[ -n "$iops" ]] && modify_cmd+=(--iops "$iops")
[[ -n "$backup_retention_days" ]] && modify_cmd+=(--backup-retention-period "$backup_retention_days")
[[ -n "$maintenance_window" ]] && modify_cmd+=(--preferred-maintenance-window "$maintenance_window")
[[ -n "$backup_window" ]] && modify_cmd+=(--preferred-backup-window "$backup_window")
[[ -n "$ca_certificate_id" ]] && modify_cmd+=(--ca-certificate-identifier "$ca_certificate_id")

case "$multi_az_mode" in
  true) modify_cmd+=(--multi-az) ;;
  false) modify_cmd+=(--no-multi-az) ;;
esac

case "$auto_minor_upgrade_mode" in
  true) modify_cmd+=(--auto-minor-version-upgrade) ;;
  false) modify_cmd+=(--no-auto-minor-version-upgrade) ;;
esac

case "$deletion_protection_mode" in
  true) modify_cmd+=(--deletion-protection) ;;
  false) modify_cmd+=(--no-deletion-protection) ;;
esac

$apply_immediately && modify_cmd+=(--apply-immediately)

if $dry_run; then
  printf 'DRY-RUN:' >&2
  printf ' %q' "${modify_cmd[@]}" >&2
  printf '\n' >&2
  log "dry-run mode: instance not modified"
  exit 0
fi

"${modify_cmd[@]}" --query 'DBInstance.DBInstanceIdentifier' --output text > /dev/null
log "modify requested for DB instance: $identifier"

if $wait_enabled; then
  wait_for_instance_available
  log "instance is available after modify: $identifier"
fi

exit 0
