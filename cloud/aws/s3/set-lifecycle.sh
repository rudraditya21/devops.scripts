#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: set-lifecycle.sh [OPTIONS]

Apply S3 bucket lifecycle configuration from a JSON file.

Options:
  --bucket NAME       Bucket name (required)
  --file PATH         Lifecycle JSON file path (required)
  --region REGION     AWS region override
  --profile PROFILE   AWS CLI profile
  --validate-only     Validate JSON and read current lifecycle without applying changes
  --dry-run           Print planned commands only
  -h, --help          Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [set-lifecycle] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_bucket_name() {
  local name="$1"
  [[ ${#name} -ge 3 && ${#name} -le 63 ]] || return 1
  [[ "$name" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]] || return 1
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

validate_json_file() {
  local file="$1"
  if command_exists python3; then
    python3 -m json.tool "$file" > /dev/null 2>&1 || die "invalid JSON file: $file"
    return 0
  fi
  log "python3 not found; skipping local JSON syntax validation"
}

bucket_name=""
lifecycle_file=""
region=""
profile=""
validate_only=false
dry_run=false

while (($#)); do
  case "$1" in
    --bucket)
      shift
      (($#)) || die "--bucket requires a value"
      validate_bucket_name "$1" || die "invalid bucket name: $1"
      bucket_name="$1"
      ;;
    --file)
      shift
      (($#)) || die "--file requires a value"
      lifecycle_file="$1"
      ;;
    --region)
      shift
      (($#)) || die "--region requires a value"
      region="$1"
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
      ;;
    --validate-only)
      validate_only=true
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

[[ -n "$bucket_name" ]] || die "--bucket is required"
[[ -n "$lifecycle_file" ]] || die "--file is required"
[[ -f "$lifecycle_file" ]] || die "lifecycle file not found: $lifecycle_file"
command_exists aws || die "aws CLI is required but not found"

validate_json_file "$lifecycle_file"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

if $validate_only; then
  aws "${aws_options[@]}" s3api get-bucket-lifecycle-configuration --bucket "$bucket_name" > /dev/null 2>&1 || true
  log "validation completed for file: $lifecycle_file"
  exit 0
fi

run_cmd aws "${aws_options[@]}" s3api put-bucket-lifecycle-configuration \
  --bucket "$bucket_name" \
  --lifecycle-configuration "file://$lifecycle_file"

log "lifecycle configuration applied"
exit 0
