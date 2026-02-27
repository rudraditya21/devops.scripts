#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: detach-policy.sh [OPTIONS]

Detach managed IAM policies from a user, role, or group.

Options:
  --role NAME           Target role name (exactly one target type required)
  --user NAME           Target user name
  --group NAME          Target group name
  --policy-arn ARN      Managed policy ARN (repeatable)
  --policy-arns CSV     Comma-separated managed policy ARNs
  --profile PROFILE     AWS CLI profile
  --if-missing          Skip when policy is not attached
  --dry-run             Print planned commands only
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [detach-policy] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_principal_name() {
  [[ "$1" =~ ^[A-Za-z0-9+=,.@_-]{1,128}$ ]]
}

validate_policy_arn() {
  [[ "$1" =~ ^arn:aws[a-zA-Z-]*:iam::([0-9]{12}|aws):policy/.+$ ]]
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

principal_has_policy() {
  local principal_type="$1"
  local principal_name="$2"
  local policy_arn="$3"

  case "$principal_type" in
    role)
      aws "${aws_options[@]}" iam list-attached-role-policies --role-name "$principal_name" --query 'AttachedPolicies[].PolicyArn' --output text
      ;;
    user)
      aws "${aws_options[@]}" iam list-attached-user-policies --user-name "$principal_name" --query 'AttachedPolicies[].PolicyArn' --output text
      ;;
    group)
      aws "${aws_options[@]}" iam list-attached-group-policies --group-name "$principal_name" --query 'AttachedPolicies[].PolicyArn' --output text
      ;;
    *)
      return 1
      ;;
  esac | tr '\t' '\n' | grep -Fxq "$policy_arn"
}

detach_policy() {
  local principal_type="$1"
  local principal_name="$2"
  local policy_arn="$3"

  case "$principal_type" in
    role)
      run_cmd aws "${aws_options[@]}" iam detach-role-policy --role-name "$principal_name" --policy-arn "$policy_arn"
      ;;
    user)
      run_cmd aws "${aws_options[@]}" iam detach-user-policy --user-name "$principal_name" --policy-arn "$policy_arn"
      ;;
    group)
      run_cmd aws "${aws_options[@]}" iam detach-group-policy --group-name "$principal_name" --policy-arn "$policy_arn"
      ;;
  esac
}

role_name=""
user_name=""
group_name=""
policy_arns=()
profile=""
if_missing=false
dry_run=false

while (($#)); do
  case "$1" in
    --role)
      shift
      (($#)) || die "--role requires a value"
      validate_principal_name "$1" || die "invalid role name: $1"
      role_name="$1"
      ;;
    --user)
      shift
      (($#)) || die "--user requires a value"
      validate_principal_name "$1" || die "invalid user name: $1"
      user_name="$1"
      ;;
    --group)
      shift
      (($#)) || die "--group requires a value"
      validate_principal_name "$1" || die "invalid group name: $1"
      group_name="$1"
      ;;
    --policy-arn)
      shift
      (($#)) || die "--policy-arn requires a value"
      validate_policy_arn "$1" || die "invalid policy ARN: $1"
      policy_arns+=("$1")
      ;;
    --policy-arns)
      shift
      (($#)) || die "--policy-arns requires a value"
      IFS=',' read -r -a parsed_arns <<< "$1"
      for arn in "${parsed_arns[@]}"; do
        arn="$(trim_spaces "$arn")"
        [[ -n "$arn" ]] || continue
        validate_policy_arn "$arn" || die "invalid policy ARN in --policy-arns: $arn"
        policy_arns+=("$arn")
      done
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
      ;;
    --if-missing)
      if_missing=true
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

((${#policy_arns[@]} > 0)) || die "at least one policy ARN is required"
command_exists aws || die "aws CLI is required but not found"

target_count=0
[[ -n "$role_name" ]] && target_count=$((target_count + 1))
[[ -n "$user_name" ]] && target_count=$((target_count + 1))
[[ -n "$group_name" ]] && target_count=$((target_count + 1))
((target_count == 1)) || die "exactly one target must be specified: --role or --user or --group"

principal_type=""
principal_name=""
if [[ -n "$role_name" ]]; then
  principal_type="role"
  principal_name="$role_name"
elif [[ -n "$user_name" ]]; then
  principal_type="user"
  principal_name="$user_name"
else
  principal_type="group"
  principal_name="$group_name"
fi

aws_options=()
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

for arn in "${policy_arns[@]}"; do
  if ! principal_has_policy "$principal_type" "$principal_name" "$arn"; then
    if $if_missing; then
      log "policy not attached, skipping: $arn"
      continue
    fi
    die "policy is not attached: $arn"
  fi

  detach_policy "$principal_type" "$principal_name" "$arn"
  log "policy detached from ${principal_type} ${principal_name}: $arn"
done

exit 0
