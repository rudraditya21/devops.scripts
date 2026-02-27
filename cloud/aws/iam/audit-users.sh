#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: audit-users.sh [OPTIONS]

Audit IAM users for MFA posture and access key hygiene.

Options:
  --profile PROFILE         AWS CLI profile
  --max-key-age-days N      Flag active keys older than N days (default: 90)
  --output MODE             table|json (default: table)
  --only-findings           Show only non-compliant users
  -h, --help                Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
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

max_key_age_days=90
profile=""
output_mode="table"
only_findings=false

while (($#)); do
  case "$1" in
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
      ;;
    --max-key-age-days)
      shift
      (($#)) || die "--max-key-age-days requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--max-key-age-days must be a positive integer"
      max_key_age_days="$1"
      ;;
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        table | json) output_mode="$1" ;;
        *) die "invalid --output value: $1 (expected table|json)" ;;
      esac
      ;;
    --only-findings)
      only_findings=true
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

users=()
while read -r user; do
  [[ -n "$user" ]] || continue
  users+=("$user")
done < <(aws "${aws_options[@]}" iam list-users --query 'Users[].UserName' --output text | tr '\t' '\n')

rows=()
for user_name in "${users[@]}"; do
  mfa_count="$(aws "${aws_options[@]}" iam list-mfa-devices --user-name "$user_name" --query 'length(MFADevices)' --output text 2> /dev/null || echo 0)"
  [[ "$mfa_count" =~ ^[0-9]+$ ]] || mfa_count=0

  if ((mfa_count > 0)); then
    mfa_enabled=true
  else
    mfa_enabled=false
  fi

  has_console_access=false
  if aws "${aws_options[@]}" iam get-login-profile --user-name "$user_name" > /dev/null 2>&1; then
    has_console_access=true
  fi

  password_last_used="$(aws "${aws_options[@]}" iam get-user --user-name "$user_name" --query 'User.PasswordLastUsed' --output text 2> /dev/null || true)"
  [[ "$password_last_used" == "None" ]] && password_last_used=""

  active_keys=0
  old_active_keys=0
  while IFS=$'\t' read -r key_id key_status key_created; do
    [[ -n "$key_id" ]] || continue
    if [[ "$key_status" != "Active" ]]; then
      continue
    fi
    active_keys=$((active_keys + 1))
    key_age_days="$(days_since_iso "$key_created")"
    if ((key_age_days > max_key_age_days)); then
      old_active_keys=$((old_active_keys + 1))
    fi
  done < <(aws "${aws_options[@]}" iam list-access-keys --user-name "$user_name" --query 'AccessKeyMetadata[].[AccessKeyId,Status,CreateDate]' --output text)

  findings=()
  if $has_console_access && ! $mfa_enabled; then
    findings+=("console-without-mfa")
  fi
  if ((active_keys > 1)); then
    findings+=("multiple-active-keys")
  fi
  if ((old_active_keys > 0)); then
    findings+=("old-active-keys")
  fi

  non_compliant=false
  if ((${#findings[@]} > 0)); then
    non_compliant=true
  fi

  if $only_findings && ! $non_compliant; then
    continue
  fi

  findings_csv=""
  if ((${#findings[@]} > 0)); then
    findings_csv="$(
      IFS=','
      printf '%s' "${findings[*]}"
    )"
  fi

  rows+=("$user_name|$mfa_enabled|$has_console_access|$active_keys|$old_active_keys|$password_last_used|$non_compliant|$findings_csv")
done

if [[ "$output_mode" == "json" ]]; then
  printf '['
  for i in "${!rows[@]}"; do
    ((i > 0)) && printf ','
    row="${rows[$i]}"
    user_name="${row%%|*}"
    rest="${row#*|}"
    mfa_enabled="${rest%%|*}"
    rest="${rest#*|}"
    has_console_access="${rest%%|*}"
    rest="${rest#*|}"
    active_keys="${rest%%|*}"
    rest="${rest#*|}"
    old_active_keys="${rest%%|*}"
    rest="${rest#*|}"
    password_last_used="${rest%%|*}"
    rest="${rest#*|}"
    non_compliant="${rest%%|*}"
    findings_csv="${rest#*|}"

    printf '{'
    printf '"UserName":"%s",' "$(json_escape "$user_name")"
    printf '"MFAEnabled":%s,' "$mfa_enabled"
    printf '"ConsoleAccess":%s,' "$has_console_access"
    printf '"ActiveKeys":%s,' "$active_keys"
    printf '"OldActiveKeys":%s,' "$old_active_keys"
    printf '"PasswordLastUsed":"%s",' "$(json_escape "$password_last_used")"
    printf '"NonCompliant":%s,' "$non_compliant"
    printf '"Findings":"%s"' "$(json_escape "$findings_csv")"
    printf '}'
  done
  printf ']\n'
  exit 0
fi

printf '%-25s %-5s %-7s %-10s %-13s %-13s %s\n' "USER" "MFA" "CONSOLE" "ACTIVE_KEYS" "OLD_ACTIVE" "NON_COMPLIANT" "FINDINGS"
printf '%-25s %-5s %-7s %-10s %-13s %-13s %s\n' "----" "---" "-------" "-----------" "----------" "-------------" "--------"
for row in "${rows[@]}"; do
  user_name="${row%%|*}"
  rest="${row#*|}"
  mfa_enabled="${rest%%|*}"
  rest="${rest#*|}"
  has_console_access="${rest%%|*}"
  rest="${rest#*|}"
  active_keys="${rest%%|*}"
  rest="${rest#*|}"
  old_active_keys="${rest%%|*}"
  rest="${rest#*|}"
  password_last_used="${rest%%|*}"
  rest="${rest#*|}"
  non_compliant="${rest%%|*}"
  findings_csv="${rest#*|}"
  printf '%-25s %-5s %-7s %-10s %-13s %-13s %s\n' "$user_name" "$mfa_enabled" "$has_console_access" "$active_keys" "$old_active_keys" "$non_compliant" "$findings_csv"
done

exit 0
