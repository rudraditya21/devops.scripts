#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-role.sh [OPTIONS]

Create an IAM role with trust policy and optional managed policy attachments.

Options:
  --role-name NAME           IAM role name (required)
  --trust-policy-file PATH   Trust policy JSON file (required)
  --description TEXT         Role description
  --path PATH                IAM path (default: /)
  --max-session-duration SEC Max session duration 3600-43200 (default: 3600)
  --tag KEY=VALUE            Tag pair (repeatable)
  --tags CSV                 Comma-separated KEY=VALUE pairs
  --attach-policy-arn ARN    Attach managed policy ARN (repeatable)
  --attach-policy-arns CSV   Comma-separated policy ARNs
  --if-not-exists            Skip role creation if role exists
  --profile PROFILE          AWS CLI profile
  --dry-run                  Print planned commands only
  -h, --help                 Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-role] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_role_name() {
  [[ "$1" =~ ^[A-Za-z0-9+=,.@_-]{1,64}$ ]]
}

validate_path() {
  [[ "$1" =~ ^(/|/.+/)$ ]]
}

validate_tag_pair() {
  [[ "$1" =~ ^[^=]+=[^=].*$ ]]
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

parse_tag_pair() {
  local pair="$1"
  tag_key="${pair%%=*}"
  tag_value="${pair#*=}"
}

role_has_policy() {
  local role_name="$1"
  local policy_arn="$2"
  aws "${aws_options[@]}" iam list-attached-role-policies \
    --role-name "$role_name" \
    --query 'AttachedPolicies[].PolicyArn' \
    --output text | tr '\t' '\n' | grep -Fxq "$policy_arn"
}

role_name=""
trust_policy_file=""
description=""
role_path="/"
max_session_duration=3600
tag_pairs=()
policy_arns=()
if_not_exists=false
profile=""
dry_run=false

while (($#)); do
  case "$1" in
    --role-name)
      shift
      (($#)) || die "--role-name requires a value"
      validate_role_name "$1" || die "invalid role name: $1"
      role_name="$1"
      ;;
    --trust-policy-file)
      shift
      (($#)) || die "--trust-policy-file requires a value"
      trust_policy_file="$1"
      ;;
    --description)
      shift
      (($#)) || die "--description requires a value"
      description="$1"
      ;;
    --path)
      shift
      (($#)) || die "--path requires a value"
      validate_path "$1" || die "invalid path: $1"
      role_path="$1"
      ;;
    --max-session-duration)
      shift
      (($#)) || die "--max-session-duration requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--max-session-duration must be an integer"
      (($1 >= 3600 && $1 <= 43200)) || die "--max-session-duration must be between 3600 and 43200"
      max_session_duration="$1"
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
    --attach-policy-arn)
      shift
      (($#)) || die "--attach-policy-arn requires a value"
      validate_policy_arn "$1" || die "invalid policy ARN: $1"
      policy_arns+=("$1")
      ;;
    --attach-policy-arns)
      shift
      (($#)) || die "--attach-policy-arns requires a value"
      IFS=',' read -r -a parsed_arns <<< "$1"
      for arn in "${parsed_arns[@]}"; do
        arn="$(trim_spaces "$arn")"
        [[ -n "$arn" ]] || continue
        validate_policy_arn "$arn" || die "invalid policy ARN in --attach-policy-arns: $arn"
        policy_arns+=("$arn")
      done
      ;;
    --if-not-exists)
      if_not_exists=true
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
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

[[ -n "$role_name" ]] || die "--role-name is required"
[[ -n "$trust_policy_file" ]] || die "--trust-policy-file is required"
[[ -f "$trust_policy_file" ]] || die "trust policy file not found: $trust_policy_file"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

role_exists=false
if aws "${aws_options[@]}" iam get-role --role-name "$role_name" > /dev/null 2>&1; then
  role_exists=true
fi

if $role_exists; then
  if $if_not_exists; then
    log "role exists, skipping create: $role_name"
  else
    die "role already exists: $role_name"
  fi
else
  create_cmd=(aws "${aws_options[@]}" iam create-role
    --role-name "$role_name"
    --assume-role-policy-document "file://$trust_policy_file"
    --path "$role_path"
    --max-session-duration "$max_session_duration")

  [[ -n "$description" ]] && create_cmd+=(--description "$description")

  if ((${#tag_pairs[@]} > 0)); then
    tag_args=()
    for pair in "${tag_pairs[@]}"; do
      parse_tag_pair "$pair"
      tag_args+=("Key=${tag_key},Value=${tag_value}")
    done
    create_cmd+=(--tags "${tag_args[@]}")
  fi

  run_cmd "${create_cmd[@]}" > /dev/null
  log "role created: $role_name"
fi

for arn in "${policy_arns[@]}"; do
  if role_has_policy "$role_name" "$arn"; then
    log "policy already attached: $arn"
    continue
  fi
  run_cmd aws "${aws_options[@]}" iam attach-role-policy --role-name "$role_name" --policy-arn "$arn"
  log "policy attached: $arn"
done

exit 0
