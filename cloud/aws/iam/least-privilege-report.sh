#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: least-privilege-report.sh [OPTIONS]

Generate IAM least-privilege signals using Access Advisor service-last-accessed data.

Options:
  --user NAME           Include IAM user (repeatable)
  --users CSV           Include IAM users (comma-separated)
  --role NAME           Include IAM role (repeatable)
  --roles CSV           Include IAM roles (comma-separated)
  --group NAME          Include IAM group (repeatable)
  --groups CSV          Include IAM groups (comma-separated)
  --unused-days N       Threshold for stale service access (default: 90)
  --timeout SEC         Access Advisor job timeout (default: 600)
  --poll-interval SEC   Poll interval seconds (default: 5)
  --profile PROFILE     AWS CLI profile
  --output MODE         table|json (default: table)
  --dry-run             Print planned commands only
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [least-privilege-report] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
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

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9+=,.@_-]{1,128}$ ]]
}

days_since_iso() {
  local iso="$1"
  python3 - "$iso" << 'PY'
import datetime
import sys

value = sys.argv[1]
value = value.replace('Z', '+00:00')
parsed = datetime.datetime.fromisoformat(value)
if parsed.tzinfo is None:
    parsed = parsed.replace(tzinfo=datetime.timezone.utc)
now = datetime.datetime.now(datetime.timezone.utc)
print((now - parsed).days)
PY
}

get_arn() {
  local principal_type="$1"
  local principal_name="$2"

  case "$principal_type" in
    user)
      aws "${aws_options[@]}" iam get-user --user-name "$principal_name" --query 'User.Arn' --output text
      ;;
    role)
      aws "${aws_options[@]}" iam get-role --role-name "$principal_name" --query 'Role.Arn' --output text
      ;;
    group)
      aws "${aws_options[@]}" iam get-group --group-name "$principal_name" --query 'Group.Arn' --output text
      ;;
  esac
}

managed_policy_count() {
  local principal_type="$1"
  local principal_name="$2"

  case "$principal_type" in
    user)
      aws "${aws_options[@]}" iam list-attached-user-policies --user-name "$principal_name" --query 'length(AttachedPolicies)' --output text
      ;;
    role)
      aws "${aws_options[@]}" iam list-attached-role-policies --role-name "$principal_name" --query 'length(AttachedPolicies)' --output text
      ;;
    group)
      aws "${aws_options[@]}" iam list-attached-group-policies --group-name "$principal_name" --query 'length(AttachedPolicies)' --output text
      ;;
  esac
}

inline_policy_count() {
  local principal_type="$1"
  local principal_name="$2"

  case "$principal_type" in
    user)
      aws "${aws_options[@]}" iam list-user-policies --user-name "$principal_name" --query 'length(PolicyNames)' --output text
      ;;
    role)
      aws "${aws_options[@]}" iam list-role-policies --role-name "$principal_name" --query 'length(PolicyNames)' --output text
      ;;
    group)
      aws "${aws_options[@]}" iam list-group-policies --group-name "$principal_name" --query 'length(PolicyNames)' --output text
      ;;
  esac
}

add_csv_targets() {
  local target_type="$1"
  local csv="$2"
  local item
  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    item="$(trim_spaces "$item")"
    [[ -n "$item" ]] || continue
    validate_name "$item" || die "invalid ${target_type} name: $item"
    target_types+=("$target_type")
    target_names+=("$item")
  done
}

collect_default_targets() {
  while read -r n; do
    [[ -n "$n" ]] || continue
    target_types+=("user")
    target_names+=("$n")
  done < <(aws "${aws_options[@]}" iam list-users --query 'Users[].UserName' --output text | tr '\t' '\n')

  while read -r n; do
    [[ -n "$n" ]] || continue
    target_types+=("role")
    target_names+=("$n")
  done < <(aws "${aws_options[@]}" iam list-roles --query 'Roles[].RoleName' --output text | tr '\t' '\n')
}

wait_for_job_completion() {
  local job_id="$1"
  local start_time elapsed status
  start_time="$(date +%s)"

  while true; do
    status="$(aws "${aws_options[@]}" iam get-service-last-accessed-details --job-id "$job_id" --query 'JobStatus' --output text)"
    case "$status" in
      COMPLETED) return 0 ;;
      FAILED) die "access advisor job failed: $job_id" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for access advisor job: $job_id"
    fi

    sleep "$poll_interval_seconds"
  done
}

unused_days=90
timeout_seconds=600
poll_interval_seconds=5
profile=""
output_mode="table"
dry_run=false

target_types=()
target_names=()

while (($#)); do
  case "$1" in
    --user)
      shift
      (($#)) || die "--user requires a value"
      validate_name "$1" || die "invalid user name: $1"
      target_types+=("user")
      target_names+=("$1")
      ;;
    --users)
      shift
      (($#)) || die "--users requires a value"
      add_csv_targets "user" "$1"
      ;;
    --role)
      shift
      (($#)) || die "--role requires a value"
      validate_name "$1" || die "invalid role name: $1"
      target_types+=("role")
      target_names+=("$1")
      ;;
    --roles)
      shift
      (($#)) || die "--roles requires a value"
      add_csv_targets "role" "$1"
      ;;
    --group)
      shift
      (($#)) || die "--group requires a value"
      validate_name "$1" || die "invalid group name: $1"
      target_types+=("group")
      target_names+=("$1")
      ;;
    --groups)
      shift
      (($#)) || die "--groups requires a value"
      add_csv_targets "group" "$1"
      ;;
    --unused-days)
      shift
      (($#)) || die "--unused-days requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--unused-days must be a positive integer"
      unused_days="$1"
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
      poll_interval_seconds="$1"
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
      ;;
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        table | json) output_mode="$1" ;;
        *) die "invalid --output value: $1 (expected table|json)" ;;
      esac
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
command_exists python3 || die "python3 is required for date calculations"

aws_options=()
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

if ((${#target_types[@]} == 0)); then
  collect_default_targets
fi

rows=()
for idx in "${!target_types[@]}"; do
  principal_type="${target_types[$idx]}"
  principal_name="${target_names[$idx]}"

  arn="$(get_arn "$principal_type" "$principal_name" 2> /dev/null || true)"
  [[ -n "$arn" && "$arn" != "None" ]] || {
    log "skipping inaccessible principal: ${principal_type}/${principal_name}"
    continue
  }

  managed_count="$(managed_policy_count "$principal_type" "$principal_name" 2> /dev/null || echo 0)"
  inline_count="$(inline_policy_count "$principal_type" "$principal_name" 2> /dev/null || echo 0)"
  [[ "$managed_count" =~ ^[0-9]+$ ]] || managed_count=0
  [[ "$inline_count" =~ ^[0-9]+$ ]] || inline_count=0

  if $dry_run; then
    log "dry-run: would generate access advisor report for $principal_type/$principal_name"
    rows+=("$principal_type|$principal_name|$managed_count|$inline_count|0|0|LOW|dry-run")
    continue
  fi

  job_id="$(aws "${aws_options[@]}" iam generate-service-last-accessed-details --arn "$arn" --query 'JobId' --output text)"
  [[ -n "$job_id" && "$job_id" != "None" ]] || die "failed to start access advisor job for $principal_type/$principal_name"

  wait_for_job_completion "$job_id"

  never_used=0
  stale_used=0
  total_services=0

  while IFS=$'\t' read -r service_namespace last_authenticated; do
    [[ -n "$service_namespace" ]] || continue
    total_services=$((total_services + 1))

    if [[ "$last_authenticated" == "None" || "$last_authenticated" == "null" || -z "$last_authenticated" ]]; then
      never_used=$((never_used + 1))
      continue
    fi

    age_days="$(days_since_iso "$last_authenticated")"
    if ((age_days > unused_days)); then
      stale_used=$((stale_used + 1))
    fi
  done < <(aws "${aws_options[@]}" iam get-service-last-accessed-details \
    --job-id "$job_id" \
    --query 'ServicesLastAccessed[].[ServiceNamespace,LastAuthenticated]' \
    --output text)

  risk="LOW"
  details="services=${total_services}"
  signal_total=$((never_used + stale_used))
  if ((signal_total > 0)); then
    risk="MEDIUM"
  fi
  if ((signal_total >= 10)); then
    risk="HIGH"
  fi

  rows+=("$principal_type|$principal_name|$managed_count|$inline_count|$never_used|$stale_used|$risk|$details")
done

if [[ "$output_mode" == "json" ]]; then
  printf '['
  for i in "${!rows[@]}"; do
    ((i > 0)) && printf ','
    row="${rows[$i]}"
    principal_type="${row%%|*}"
    rest="${row#*|}"
    principal_name="${rest%%|*}"
    rest="${rest#*|}"
    managed_count="${rest%%|*}"
    rest="${rest#*|}"
    inline_count="${rest%%|*}"
    rest="${rest#*|}"
    never_used="${rest%%|*}"
    rest="${rest#*|}"
    stale_used="${rest%%|*}"
    rest="${rest#*|}"
    risk="${rest%%|*}"
    details="${rest#*|}"

    printf '{'
    printf '"PrincipalType":"%s",' "$(json_escape "$principal_type")"
    printf '"PrincipalName":"%s",' "$(json_escape "$principal_name")"
    printf '"ManagedPolicies":%s,' "$managed_count"
    printf '"InlinePolicies":%s,' "$inline_count"
    printf '"NeverUsedServices":%s,' "$never_used"
    printf '"StaleServices":%s,' "$stale_used"
    printf '"Risk":"%s",' "$(json_escape "$risk")"
    printf '"Details":"%s"' "$(json_escape "$details")"
    printf '}'
  done
  printf ']\n'
  exit 0
fi

printf '%-8s %-30s %-8s %-7s %-10s %-7s %-6s %s\n' "TYPE" "NAME" "MANAGED" "INLINE" "NEVER_USED" "STALE" "RISK" "DETAILS"
printf '%-8s %-30s %-8s %-7s %-10s %-7s %-6s %s\n' "----" "----" "-------" "------" "----------" "-----" "----" "-------"
for row in "${rows[@]}"; do
  principal_type="${row%%|*}"
  rest="${row#*|}"
  principal_name="${rest%%|*}"
  rest="${rest#*|}"
  managed_count="${rest%%|*}"
  rest="${rest#*|}"
  inline_count="${rest%%|*}"
  rest="${rest#*|}"
  never_used="${rest%%|*}"
  rest="${rest#*|}"
  stale_used="${rest%%|*}"
  rest="${rest#*|}"
  risk="${rest%%|*}"
  details="${rest#*|}"
  printf '%-8s %-30s %-8s %-7s %-10s %-7s %-6s %s\n' "$principal_type" "$principal_name" "$managed_count" "$inline_count" "$never_used" "$stale_used" "$risk" "$details"
done

exit 0
