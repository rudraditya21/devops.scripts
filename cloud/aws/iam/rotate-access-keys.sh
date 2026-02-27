#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: rotate-access-keys.sh [OPTIONS]

Rotate IAM user access keys with optional post-rotation hardening actions.

Options:
  --user NAME              IAM user name (required)
  --profile PROFILE        AWS CLI profile
  --deactivate-old-keys    Deactivate previously active keys after new key creation
  --delete-inactive-keys   Delete inactive keys (pre/post rotation cleanup)
  --output MODE            env|json|table (default: env)
  --yes                    Required for deactivation/deletion actions
  --dry-run                Print planned commands only
  -h, --help               Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [rotate-access-keys] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_user_name() {
  [[ "$1" =~ ^[A-Za-z0-9+=,.@_-]{1,64}$ ]]
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

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

refresh_key_metadata() {
  key_ids=()
  key_statuses=()
  key_dates=()

  while IFS=$'\t' read -r key_id key_status key_date; do
    [[ -n "$key_id" ]] || continue
    key_ids+=("$key_id")
    key_statuses+=("$key_status")
    key_dates+=("$key_date")
  done < <(aws "${aws_options[@]}" iam list-access-keys \
    --user-name "$user_name" \
    --query 'AccessKeyMetadata[].[AccessKeyId,Status,CreateDate]' \
    --output text | sort -k3)
}

oldest_inactive_key_id() {
  local i
  for i in "${!key_ids[@]}"; do
    if [[ "${key_statuses[$i]}" == "Inactive" ]]; then
      printf '%s' "${key_ids[$i]}"
      return 0
    fi
  done
  return 1
}

emit_credentials() {
  local mode="$1"
  local access_key_id="$2"
  local secret_access_key="$3"
  local create_date="$4"

  case "$mode" in
    env)
      printf 'AWS_ACCESS_KEY_ID=%s\n' "$access_key_id"
      printf 'AWS_SECRET_ACCESS_KEY=%s\n' "$secret_access_key"
      printf 'AWS_ACCESS_KEY_CREATE_DATE=%s\n' "$create_date"
      ;;
    json)
      printf '{"UserName":"%s","AccessKeyId":"%s","SecretAccessKey":"%s","CreateDate":"%s"}\n' \
        "$(json_escape "$user_name")" \
        "$(json_escape "$access_key_id")" \
        "$(json_escape "$secret_access_key")" \
        "$(json_escape "$create_date")"
      ;;
    table)
      printf '%-20s %s\n' 'UserName' "$user_name"
      printf '%-20s %s\n' 'AccessKeyId' "$access_key_id"
      printf '%-20s %s\n' 'SecretAccessKey' "$secret_access_key"
      printf '%-20s %s\n' 'CreateDate' "$create_date"
      ;;
  esac
}

user_name=""
profile=""
deactivate_old_keys=false
delete_inactive_keys=false
output_mode="env"
yes=false
dry_run=false

while (($#)); do
  case "$1" in
    --user)
      shift
      (($#)) || die "--user requires a value"
      validate_user_name "$1" || die "invalid user name: $1"
      user_name="$1"
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
      ;;
    --deactivate-old-keys)
      deactivate_old_keys=true
      ;;
    --delete-inactive-keys)
      delete_inactive_keys=true
      ;;
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        env | json | table) output_mode="$1" ;;
        *) die "invalid --output value: $1 (expected env|json|table)" ;;
      esac
      ;;
    --yes)
      yes=true
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

[[ -n "$user_name" ]] || die "--user is required"
command_exists aws || die "aws CLI is required but not found"

if ! $dry_run && { $deactivate_old_keys || $delete_inactive_keys; } && ! $yes; then
  die "--yes is required when using --deactivate-old-keys or --delete-inactive-keys"
fi

aws_options=()
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

aws "${aws_options[@]}" iam get-user --user-name "$user_name" > /dev/null 2>&1 || die "IAM user not found or inaccessible: $user_name"

refresh_key_metadata
original_active_keys=()
for i in "${!key_ids[@]}"; do
  if [[ "${key_statuses[$i]}" == "Active" ]]; then
    original_active_keys+=("${key_ids[$i]}")
  fi
done

if ((${#key_ids[@]} >= 2)); then
  if $delete_inactive_keys; then
    inactive_key="$(oldest_inactive_key_id || true)"
    [[ -n "$inactive_key" ]] || die "cannot rotate: user already has 2 active keys and no inactive key to delete"

    run_cmd aws "${aws_options[@]}" iam delete-access-key --user-name "$user_name" --access-key-id "$inactive_key"
    log "deleted inactive key to free slot: $inactive_key"
    refresh_key_metadata
  else
    die "cannot rotate: user already has 2 access keys (use --delete-inactive-keys if applicable)"
  fi
fi

if $dry_run; then
  run_cmd aws "${aws_options[@]}" iam create-access-key --user-name "$user_name"
  if $deactivate_old_keys; then
    for key_id in "${original_active_keys[@]}"; do
      run_cmd aws "${aws_options[@]}" iam update-access-key --user-name "$user_name" --access-key-id "$key_id" --status Inactive
    done
  fi
  if $delete_inactive_keys; then
    run_cmd aws "${aws_options[@]}" iam list-access-keys --user-name "$user_name"
  fi
  printf 'AWS_ACCESS_KEY_ID=<dry-run>\n'
  printf 'AWS_SECRET_ACCESS_KEY=<dry-run>\n'
  printf 'AWS_ACCESS_KEY_CREATE_DATE=<dry-run>\n'
  exit 0
fi

read -r new_access_key_id new_secret_access_key new_create_date < <(aws "${aws_options[@]}" iam create-access-key \
  --user-name "$user_name" \
  --query 'AccessKey.[AccessKeyId,SecretAccessKey,CreateDate]' \
  --output text)

[[ -n "$new_access_key_id" && -n "$new_secret_access_key" ]] || die "failed to create new access key"
log "new access key created: $new_access_key_id"

if $deactivate_old_keys; then
  for key_id in "${original_active_keys[@]}"; do
    [[ "$key_id" == "$new_access_key_id" ]] && continue
    run_cmd aws "${aws_options[@]}" iam update-access-key --user-name "$user_name" --access-key-id "$key_id" --status Inactive
    log "deactivated old key: $key_id"
  done
fi

if $delete_inactive_keys; then
  refresh_key_metadata
  for i in "${!key_ids[@]}"; do
    key_id="${key_ids[$i]}"
    key_status="${key_statuses[$i]}"
    if [[ "$key_status" == "Inactive" && "$key_id" != "$new_access_key_id" ]]; then
      run_cmd aws "${aws_options[@]}" iam delete-access-key --user-name "$user_name" --access-key-id "$key_id"
      log "deleted inactive key: $key_id"
    fi
  done
fi

emit_credentials "$output_mode" "$new_access_key_id" "$new_secret_access_key" "$new_create_date"
exit 0
