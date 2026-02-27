#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-bucket.sh [OPTIONS]

Create an S3 bucket with optional tags and versioning.

Options:
  --bucket NAME        Bucket name (required)
  --region REGION      Bucket region (default: aws config region or us-east-1)
  --profile PROFILE    AWS CLI profile
  --tag KEY=VALUE      Tag pair (repeatable)
  --tags CSV           Comma-separated KEY=VALUE pairs
  --enable-versioning  Enable bucket versioning after creation
  --if-not-exists      Return success if bucket already exists and is accessible
  --dry-run            Print planned commands only
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-bucket] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_bucket_name() {
  local name="$1"
  [[ ${#name} -ge 3 && ${#name} -le 63 ]] || return 1
  [[ "$name" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]] || return 1
  [[ "$name" != *".."* ]] || return 1
  [[ "$name" != *"-."* ]] || return 1
  [[ "$name" != *".-"* ]] || return 1
  [[ ! "$name" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
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

bucket_name=""
bucket_region=""
profile=""
tag_pairs=()
enable_versioning=false
if_not_exists=false
dry_run=false

while (($#)); do
  case "$1" in
    --bucket)
      shift
      (($#)) || die "--bucket requires a value"
      validate_bucket_name "$1" || die "invalid bucket name: $1"
      bucket_name="$1"
      ;;
    --region)
      shift
      (($#)) || die "--region requires a value"
      bucket_region="$1"
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
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
    --enable-versioning)
      enable_versioning=true
      ;;
    --if-not-exists)
      if_not_exists=true
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

aws_options=()
if [[ -n "$profile" ]]; then
  aws_options+=(--profile "$profile")
fi

if [[ -z "$bucket_region" ]]; then
  bucket_region="$(aws "${aws_options[@]}" configure get region 2> /dev/null || true)"
  [[ -n "$bucket_region" ]] || bucket_region="us-east-1"
fi
aws_options+=(--region "$bucket_region")

if aws "${aws_options[@]}" s3api head-bucket --bucket "$bucket_name" > /dev/null 2>&1; then
  if $if_not_exists; then
    log "bucket already exists and is accessible: $bucket_name"
    exit 0
  fi
  die "bucket already exists and is accessible: $bucket_name"
fi

create_cmd=(aws "${aws_options[@]}" s3api create-bucket --bucket "$bucket_name")
if [[ "$bucket_region" != "us-east-1" ]]; then
  create_cmd+=(--create-bucket-configuration "LocationConstraint=$bucket_region")
fi
run_cmd "${create_cmd[@]}" > /dev/null
log "bucket created: $bucket_name"

if ((${#tag_pairs[@]} > 0)); then
  tag_set=()
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    tag_set+=("{Key=$tag_key,Value=$tag_value}")
  done

  tag_payload="TagSet=[${tag_set[*]}]"
  run_cmd aws "${aws_options[@]}" s3api put-bucket-tagging --bucket "$bucket_name" --tagging "$tag_payload"
  log "tags applied to bucket"
fi

if $enable_versioning; then
  run_cmd aws "${aws_options[@]}" s3api put-bucket-versioning --bucket "$bucket_name" --versioning-configuration Status=Enabled
  log "versioning enabled for bucket"
fi

exit 0
