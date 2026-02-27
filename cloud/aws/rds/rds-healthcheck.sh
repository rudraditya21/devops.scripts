#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: rds-healthcheck.sh [OPTIONS]

Validate AWS RDS automation readiness for this environment.

Options:
  --region REGION        AWS region override
  --profile PROFILE      AWS CLI profile
  --instance-id ID       Optional DB instance identifier for targeted checks
  --strict               Treat WARN checks as failure
  --json                 Emit JSON report
  -h, --help             Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_identifier() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ && ! "$1" =~ -- && ! "$1" =~ -$ ]]
}

add_check() {
  checks_name+=("$1")
  checks_status+=("$2")
  checks_detail+=("$3")
}

output_text() {
  local i
  printf '%-34s %-8s %s\n' "CHECK" "STATUS" "DETAIL"
  printf '%-34s %-8s %s\n' "-----" "------" "------"
  for i in "${!checks_name[@]}"; do
    printf '%-34s %-8s %s\n' "${checks_name[$i]}" "${checks_status[$i]}" "${checks_detail[$i]}"
  done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass_count" "$warn_count" "$fail_count"
}

output_json() {
  local i
  printf '{'
  printf '"summary":{'
  printf '"pass":%s,' "$pass_count"
  printf '"warn":%s,' "$warn_count"
  printf '"fail":%s' "$fail_count"
  printf '},'
  printf '"checks":['
  for i in "${!checks_name[@]}"; do
    ((i > 0)) && printf ','
    printf '{'
    printf '"name":"%s",' "$(json_escape "${checks_name[$i]}")"
    printf '"status":"%s",' "$(json_escape "${checks_status[$i]}")"
    printf '"detail":"%s"' "$(json_escape "${checks_detail[$i]}")"
    printf '}'
  done
  printf ']'
  printf '}\n'
}

aws_options=()
instance_id=""
strict_mode=false
json_mode=false
checks_name=()
checks_status=()
checks_detail=()

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
    --instance-id)
      shift
      (($#)) || die "--instance-id requires a value"
      validate_identifier "$1" || die "invalid --instance-id value"
      instance_id="$1"
      ;;
    --strict)
      strict_mode=true
      ;;
    --json)
      json_mode=true
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

if command_exists aws; then
  add_check "cmd:aws" "PASS" "aws CLI found"
else
  add_check "cmd:aws" "FAIL" "aws CLI not found"
fi

if command_exists aws; then
  identity_line="$(aws "${aws_options[@]}" sts get-caller-identity --query '[Account,Arn]' --output text 2> /dev/null || true)"
  if [[ -n "$identity_line" && "$identity_line" != "None" ]]; then
    add_check "auth:sts" "PASS" "$identity_line"
  else
    add_check "auth:sts" "FAIL" "unable to call sts get-caller-identity"
  fi

  configured_region="$(aws "${aws_options[@]}" configure get region 2> /dev/null || true)"
  if [[ -n "$configured_region" ]]; then
    add_check "config:region" "PASS" "$configured_region"
  else
    add_check "config:region" "WARN" "no default region configured (use --region)"
  fi

  if aws "${aws_options[@]}" rds describe-db-instances --max-items 1 --query 'DBInstances[0].DBInstanceIdentifier' --output text > /dev/null 2>&1; then
    add_check "perm:rds-describe-db-instances" "PASS" "allowed"
  else
    add_check "perm:rds-describe-db-instances" "FAIL" "not allowed"
  fi

  instance_count="$(aws "${aws_options[@]}" rds describe-db-instances --query 'length(DBInstances)' --output text 2> /dev/null || true)"
  if [[ "$instance_count" =~ ^[0-9]+$ ]]; then
    if ((instance_count > 0)); then
      add_check "rds:instance-count" "PASS" "$instance_count instance(s) visible"
    else
      add_check "rds:instance-count" "WARN" "no DB instances found in scope"
    fi
  else
    add_check "rds:instance-count" "FAIL" "failed to query DB instance inventory"
  fi

  if [[ -n "$instance_id" ]]; then
    status="$(aws "${aws_options[@]}" rds describe-db-instances --db-instance-identifier "$instance_id" --query 'DBInstances[0].DBInstanceStatus' --output text 2> /dev/null || true)"
    if [[ -z "$status" || "$status" == "None" ]]; then
      add_check "rds:instance:$instance_id" "FAIL" "instance not found or inaccessible"
    else
      if [[ "$status" == "available" ]]; then
        add_check "rds:instance:$instance_id" "PASS" "status=$status"
      else
        add_check "rds:instance:$instance_id" "WARN" "status=$status"
      fi

      storage_encrypted="$(aws "${aws_options[@]}" rds describe-db-instances --db-instance-identifier "$instance_id" --query 'DBInstances[0].StorageEncrypted' --output text 2> /dev/null || true)"
      if [[ "$storage_encrypted" == "True" ]]; then
        add_check "rds:encryption:$instance_id" "PASS" "storage encryption enabled"
      elif [[ "$storage_encrypted" == "False" ]]; then
        add_check "rds:encryption:$instance_id" "WARN" "storage encryption disabled"
      else
        add_check "rds:encryption:$instance_id" "FAIL" "unable to determine storage encryption"
      fi

      backup_retention="$(aws "${aws_options[@]}" rds describe-db-instances --db-instance-identifier "$instance_id" --query 'DBInstances[0].BackupRetentionPeriod' --output text 2> /dev/null || true)"
      if [[ "$backup_retention" =~ ^[0-9]+$ ]]; then
        if ((backup_retention > 0)); then
          add_check "rds:backup-retention:$instance_id" "PASS" "backup retention=$backup_retention day(s)"
        else
          add_check "rds:backup-retention:$instance_id" "WARN" "backup retention disabled"
        fi
      else
        add_check "rds:backup-retention:$instance_id" "FAIL" "unable to determine backup retention"
      fi

      deletion_protection="$(aws "${aws_options[@]}" rds describe-db-instances --db-instance-identifier "$instance_id" --query 'DBInstances[0].DeletionProtection' --output text 2> /dev/null || true)"
      if [[ "$deletion_protection" == "True" ]]; then
        add_check "rds:deletion-protection:$instance_id" "PASS" "deletion protection enabled"
      elif [[ "$deletion_protection" == "False" ]]; then
        add_check "rds:deletion-protection:$instance_id" "WARN" "deletion protection disabled"
      else
        add_check "rds:deletion-protection:$instance_id" "FAIL" "unable to determine deletion protection"
      fi
    fi
  fi
fi

pass_count=0
warn_count=0
fail_count=0
for status in "${checks_status[@]}"; do
  case "$status" in
    PASS) pass_count=$((pass_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
    FAIL) fail_count=$((fail_count + 1)) ;;
  esac
done

if $json_mode; then
  output_json
else
  output_text
fi

if ((fail_count > 0)); then
  exit 1
fi

if $strict_mode && ((warn_count > 0)); then
  exit 1
fi

exit 0
