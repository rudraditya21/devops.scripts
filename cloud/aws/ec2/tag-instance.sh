#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: tag-instance.sh [OPTIONS]

Apply tags to one or more EC2 instances.

Options:
  --id INSTANCE_ID      Instance ID (repeatable)
  --ids CSV             Comma-separated instance IDs
  --tag KEY=VALUE       Tag pair (repeatable)
  --tags CSV            Comma-separated KEY=VALUE pairs
  --if-missing          Only add keys that do not already exist on each instance
  --region REGION       AWS region
  --profile PROFILE     AWS CLI profile
  --dry-run             Print actions without executing
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [tag-instance] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_instance_id() {
  [[ "$1" =~ ^i-[a-f0-9]{8,17}$ ]]
}

validate_tag_pair() {
  [[ "$1" =~ ^[^=]+=[^=].*$ ]]
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

aws_options=()
instance_ids=()
tag_pairs=()
if_missing=false
dry_run=false

while (($#)); do
  case "$1" in
    --id)
      shift
      (($#)) || die "--id requires a value"
      validate_instance_id "$1" || die "invalid instance ID: $1"
      instance_ids+=("$1")
      ;;
    --ids)
      shift
      (($#)) || die "--ids requires a value"
      IFS=',' read -r -a parsed_ids <<< "$1"
      for id in "${parsed_ids[@]}"; do
        id="$(trim_spaces "$id")"
        [[ -n "$id" ]] || continue
        validate_instance_id "$id" || die "invalid instance ID in --ids: $id"
        instance_ids+=("$id")
      done
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
    --if-missing)
      if_missing=true
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
((${#instance_ids[@]} > 0)) || die "at least one instance ID is required (--id/--ids)"
((${#tag_pairs[@]} > 0)) || die "at least one tag is required (--tag/--tags)"

if ! $if_missing; then
  tag_args=()
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    tag_args+=("Key=${tag_key},Value=${tag_value}")
  done

  run_cmd aws "${aws_options[@]}" ec2 create-tags \
    --resources "${instance_ids[@]}" \
    --tags "${tag_args[@]}"
  log "tag update requested for instances: ${instance_ids[*]}"
  exit 0
fi

for instance_id in "${instance_ids[@]}"; do
  existing_keys="$(aws "${aws_options[@]}" ec2 describe-tags \
    --filters Name=resource-id,Values="$instance_id" Name=resource-type,Values=instance \
    --query 'Tags[].Key' \
    --output text)"

  tag_args=()
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    if [[ " $existing_keys " == *" $tag_key "* ]]; then
      continue
    fi
    tag_args+=("Key=${tag_key},Value=${tag_value}")
  done

  if ((${#tag_args[@]} == 0)); then
    log "no missing tags for $instance_id"
    continue
  fi

  run_cmd aws "${aws_options[@]}" ec2 create-tags \
    --resources "$instance_id" \
    --tags "${tag_args[@]}"
  log "applied missing tags to $instance_id"
done

exit 0
