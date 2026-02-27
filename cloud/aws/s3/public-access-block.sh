#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: public-access-block.sh [OPTIONS]

Configure S3 Public Access Block settings for a bucket.

Options:
  --bucket NAME                    Bucket name (required)
  --mode MODE                      block|allow|custom (default: block)
  --block-public-acls BOOL         true|false (custom mode)
  --ignore-public-acls BOOL        true|false (custom mode)
  --block-public-policy BOOL       true|false (custom mode)
  --restrict-public-buckets BOOL   true|false (custom mode)
  --region REGION                  AWS region override
  --profile PROFILE                AWS CLI profile
  --dry-run                        Print planned commands only
  -h, --help                       Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [public-access-block] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_bucket_name() {
  local name="$1"
  [[ ${#name} -ge 3 && ${#name} -le 63 ]] || return 1
  [[ "$name" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]] || return 1
}

normalize_bool() {
  case "$1" in
    true | 1 | yes | on) printf 'true' ;;
    false | 0 | no | off) printf 'false' ;;
    *) die "invalid boolean value: $1 (use true/false)" ;;
  esac
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

bucket_name=""
mode="block"
region=""
profile=""
dry_run=false

block_public_acls=""
ignore_public_acls=""
block_public_policy=""
restrict_public_buckets=""

while (($#)); do
  case "$1" in
    --bucket)
      shift
      (($#)) || die "--bucket requires a value"
      validate_bucket_name "$1" || die "invalid bucket name: $1"
      bucket_name="$1"
      ;;
    --mode)
      shift
      (($#)) || die "--mode requires a value"
      case "$1" in
        block | allow | custom) mode="$1" ;;
        *) die "invalid --mode value: $1 (expected block|allow|custom)" ;;
      esac
      ;;
    --block-public-acls)
      shift
      (($#)) || die "--block-public-acls requires a value"
      block_public_acls="$(normalize_bool "$1")"
      mode="custom"
      ;;
    --ignore-public-acls)
      shift
      (($#)) || die "--ignore-public-acls requires a value"
      ignore_public_acls="$(normalize_bool "$1")"
      mode="custom"
      ;;
    --block-public-policy)
      shift
      (($#)) || die "--block-public-policy requires a value"
      block_public_policy="$(normalize_bool "$1")"
      mode="custom"
      ;;
    --restrict-public-buckets)
      shift
      (($#)) || die "--restrict-public-buckets requires a value"
      restrict_public_buckets="$(normalize_bool "$1")"
      mode="custom"
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
command_exists aws || die "aws CLI is required but not found"

case "$mode" in
  block)
    block_public_acls="true"
    ignore_public_acls="true"
    block_public_policy="true"
    restrict_public_buckets="true"
    ;;
  allow)
    block_public_acls="false"
    ignore_public_acls="false"
    block_public_policy="false"
    restrict_public_buckets="false"
    ;;
  custom)
    [[ -n "$block_public_acls" ]] || block_public_acls="true"
    [[ -n "$ignore_public_acls" ]] || ignore_public_acls="true"
    [[ -n "$block_public_policy" ]] || block_public_policy="true"
    [[ -n "$restrict_public_buckets" ]] || restrict_public_buckets="true"
    ;;
esac

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

config_payload="BlockPublicAcls=${block_public_acls},IgnorePublicAcls=${ignore_public_acls},BlockPublicPolicy=${block_public_policy},RestrictPublicBuckets=${restrict_public_buckets}"

run_cmd aws "${aws_options[@]}" s3api put-public-access-block --bucket "$bucket_name" --public-access-block-configuration "$config_payload"
log "public access block configuration applied"

if ! $dry_run; then
  aws "${aws_options[@]}" s3api get-public-access-block --bucket "$bucket_name" --query 'PublicAccessBlockConfiguration' --output table
fi

exit 0
