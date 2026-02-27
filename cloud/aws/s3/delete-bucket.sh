#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: delete-bucket.sh [OPTIONS]

Delete an S3 bucket, optionally removing all objects/versions first.

Options:
  --bucket NAME       Bucket name (required)
  --region REGION     AWS region override
  --profile PROFILE   AWS CLI profile
  --force             Remove all objects/versions and multipart uploads before delete
  --if-exists         Return success if bucket does not exist or is inaccessible
  --yes               Required for actual deletion (ignored in --dry-run)
  --dry-run           Print planned commands only
  -h, --help          Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [delete-bucket] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
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

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

purge_bucket() {
  local key version_id upload_id

  run_cmd aws "${aws_options[@]}" s3 rm "s3://$bucket_name" --recursive > /dev/null

  while IFS=$'\t' read -r key version_id; do
    [[ -n "$key" && -n "$version_id" ]] || continue
    run_cmd aws "${aws_options[@]}" s3api delete-object --bucket "$bucket_name" --key "$key" --version-id "$version_id" > /dev/null
  done < <(aws "${aws_options[@]}" s3api list-object-versions \
    --bucket "$bucket_name" \
    --query '[Versions[].[Key,VersionId],DeleteMarkers[].[Key,VersionId]][][]' \
    --output text)

  while IFS=$'\t' read -r upload_id key; do
    [[ -n "$upload_id" && -n "$key" ]] || continue
    run_cmd aws "${aws_options[@]}" s3api abort-multipart-upload --bucket "$bucket_name" --key "$key" --upload-id "$upload_id" > /dev/null
  done < <(aws "${aws_options[@]}" s3api list-multipart-uploads \
    --bucket "$bucket_name" \
    --query 'Uploads[].[UploadId,Key]' \
    --output text 2> /dev/null || true)
}

bucket_name=""
region=""
profile=""
force_delete=false
if_exists=false
yes=false
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
      region="$1"
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
      ;;
    --force)
      force_delete=true
      ;;
    --if-exists)
      if_exists=true
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

[[ -n "$bucket_name" ]] || die "--bucket is required"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")
[[ -n "$region" ]] && aws_options+=(--region "$region")

if ! aws "${aws_options[@]}" s3api head-bucket --bucket "$bucket_name" > /dev/null 2>&1; then
  if $if_exists; then
    log "bucket not found or inaccessible, skipping: $bucket_name"
    exit 0
  fi
  die "bucket not found or inaccessible: $bucket_name"
fi

if ! $dry_run && ! $yes; then
  die "--yes is required for deletion"
fi

if $force_delete; then
  purge_bucket
  log "bucket contents purged"
fi

run_cmd aws "${aws_options[@]}" s3api delete-bucket --bucket "$bucket_name"
log "bucket deleted: $bucket_name"

exit 0
