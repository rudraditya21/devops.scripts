#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-instance.sh [OPTIONS]

Create an AWS RDS DB instance with validated and safe defaults.

Options:
  --identifier ID              DB instance identifier (required)
  --engine ENGINE              DB engine (required, non-Aurora)
  --instance-class CLASS       DB instance class (required, example: db.t3.medium)
  --allocated-storage GB       Allocated storage in GiB (required)
  --engine-version VERSION     Engine version
  --db-name NAME               Initial database name
  --master-username USER       Master username (required unless --manage-master-user-password)
  --master-password PASS       Master password (required unless --manage-master-user-password)
  --manage-master-user-password Use AWS-managed master password
  --storage-type TYPE          Storage type (default: gp3)
  --backup-retention-days N    Backup retention days (default: 7)
  --port PORT                  Database port
  --db-subnet-group NAME       DB subnet group name
  --parameter-group NAME       DB parameter group name
  --option-group NAME          DB option group name
  --vpc-security-group-id SG   VPC security group ID (repeatable)
  --vpc-security-group-ids CSV Comma-separated VPC security group IDs
  --multi-az                   Enable Multi-AZ deployment
  --no-multi-az                Disable Multi-AZ deployment (default)
  --publicly-accessible        Enable public accessibility
  --no-publicly-accessible     Disable public accessibility (default)
  --deletion-protection        Enable deletion protection (default)
  --no-deletion-protection     Disable deletion protection
  --tag KEY=VALUE              Tag pair (repeatable)
  --tags CSV                   Comma-separated tag pairs
  --wait                       Wait until DB instance becomes available
  --timeout SEC                Wait timeout in seconds (default: 3600)
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
  printf '%s [create-instance] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

validate_engine() {
  [[ "$1" =~ ^[a-z0-9-]+$ ]]
}

validate_instance_class() {
  [[ "$1" =~ ^db\.[a-z0-9.-]+$ ]]
}

validate_storage_type() {
  [[ "$1" =~ ^(gp2|gp3|io1|io2|standard)$ ]]
}

validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (("$1" >= 1 && "$1" <= 65535))
}

validate_tag_pair() {
  [[ "$1" =~ ^[^=]+=[^=].*$ ]]
}

parse_tag_pair() {
  local pair="$1"
  tag_key="${pair%%=*}"
  tag_value="${pair#*=}"
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
      die "timeout waiting for instance $identifier to become available"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
identifier=""
engine=""
instance_class=""
allocated_storage=""
engine_version=""
db_name=""
master_username=""
master_password=""
manage_master_user_password=false
storage_type="gp3"
backup_retention_days=7
port=""
db_subnet_group=""
parameter_group=""
option_group=""
vpc_security_group_ids=()
multi_az=false
publicly_accessible=false
deletion_protection=true
tag_pairs=()
wait_enabled=false
timeout_seconds=3600
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
    --engine)
      shift
      (($#)) || die "--engine requires a value"
      validate_engine "$1" || die "invalid --engine value"
      engine="$1"
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
    --engine-version)
      shift
      (($#)) || die "--engine-version requires a value"
      engine_version="$1"
      ;;
    --db-name)
      shift
      (($#)) || die "--db-name requires a value"
      db_name="$1"
      ;;
    --master-username)
      shift
      (($#)) || die "--master-username requires a value"
      master_username="$1"
      ;;
    --master-password)
      shift
      (($#)) || die "--master-password requires a value"
      master_password="$1"
      ;;
    --manage-master-user-password)
      manage_master_user_password=true
      ;;
    --storage-type)
      shift
      (($#)) || die "--storage-type requires a value"
      validate_storage_type "$1" || die "invalid --storage-type value"
      storage_type="$1"
      ;;
    --backup-retention-days)
      shift
      (($#)) || die "--backup-retention-days requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--backup-retention-days must be an integer"
      (("$1" >= 0 && "$1" <= 35)) || die "--backup-retention-days must be between 0 and 35"
      backup_retention_days="$1"
      ;;
    --port)
      shift
      (($#)) || die "--port requires a value"
      validate_port "$1" || die "--port must be between 1 and 65535"
      port="$1"
      ;;
    --db-subnet-group)
      shift
      (($#)) || die "--db-subnet-group requires a value"
      db_subnet_group="$1"
      ;;
    --parameter-group)
      shift
      (($#)) || die "--parameter-group requires a value"
      parameter_group="$1"
      ;;
    --option-group)
      shift
      (($#)) || die "--option-group requires a value"
      option_group="$1"
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
    --multi-az)
      multi_az=true
      ;;
    --no-multi-az)
      multi_az=false
      ;;
    --publicly-accessible)
      publicly_accessible=true
      ;;
    --no-publicly-accessible)
      publicly_accessible=false
      ;;
    --deletion-protection)
      deletion_protection=true
      ;;
    --no-deletion-protection)
      deletion_protection=false
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
[[ -n "$engine" ]] || die "--engine is required"
[[ -n "$instance_class" ]] || die "--instance-class is required"
[[ -n "$allocated_storage" ]] || die "--allocated-storage is required"

[[ "$engine" =~ ^aurora ]] && die "Aurora engines are not supported by create-instance.sh (use cluster workflow)"

if $manage_master_user_password; then
  [[ -z "$master_password" ]] || die "--master-password cannot be used with --manage-master-user-password"
  [[ -n "$master_username" ]] || die "--master-username is required with --manage-master-user-password"
else
  [[ -n "$master_username" ]] || die "--master-username is required"
  [[ -n "$master_password" ]] || die "--master-password is required"
fi

existing="$(aws "${aws_options[@]}" rds describe-db-instances \
  --db-instance-identifier "$identifier" \
  --query 'DBInstances[0].DBInstanceIdentifier' \
  --output text 2> /dev/null || true)"

if [[ -n "$existing" && "$existing" != "None" ]]; then
  die "DB instance already exists: $identifier"
fi

create_cmd=(
  aws "${aws_options[@]}" rds create-db-instance
  --db-instance-identifier "$identifier"
  --engine "$engine"
  --db-instance-class "$instance_class"
  --allocated-storage "$allocated_storage"
  --storage-type "$storage_type"
  --backup-retention-period "$backup_retention_days"
)

[[ -n "$engine_version" ]] && create_cmd+=(--engine-version "$engine_version")
[[ -n "$db_name" ]] && create_cmd+=(--db-name "$db_name")
[[ -n "$db_subnet_group" ]] && create_cmd+=(--db-subnet-group-name "$db_subnet_group")
[[ -n "$parameter_group" ]] && create_cmd+=(--db-parameter-group-name "$parameter_group")
[[ -n "$option_group" ]] && create_cmd+=(--option-group-name "$option_group")
[[ -n "$port" ]] && create_cmd+=(--port "$port")

if $manage_master_user_password; then
  create_cmd+=(--master-username "$master_username" --manage-master-user-password)
else
  create_cmd+=(--master-username "$master_username" --master-user-password "$master_password")
fi

if $multi_az; then
  create_cmd+=(--multi-az)
else
  create_cmd+=(--no-multi-az)
fi

if $publicly_accessible; then
  create_cmd+=(--publicly-accessible)
else
  create_cmd+=(--no-publicly-accessible)
fi

if $deletion_protection; then
  create_cmd+=(--deletion-protection)
else
  create_cmd+=(--no-deletion-protection)
fi

if ((${#vpc_security_group_ids[@]} > 0)); then
  create_cmd+=(--vpc-security-group-ids "${vpc_security_group_ids[@]}")
fi

if ((${#tag_pairs[@]} > 0)); then
  tag_args=()
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    tag_args+=("Key=${tag_key},Value=${tag_value}")
  done
  create_cmd+=(--tags "${tag_args[@]}")
fi

if $dry_run; then
  run_cmd "${create_cmd[@]}"
  log "dry-run mode: instance not created"
  exit 0
fi

created_id="$("${create_cmd[@]}" --query 'DBInstance.DBInstanceIdentifier' --output text)"
[[ -n "$created_id" && "$created_id" != "None" ]] || die "failed to obtain DBInstanceIdentifier from create-db-instance"
log "create requested for DB instance: $created_id"

if $wait_enabled; then
  wait_for_instance_available
  log "instance is available: $created_id"
fi

printf '%s\n' "$created_id"
exit 0
