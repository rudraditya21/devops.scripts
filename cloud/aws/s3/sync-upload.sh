#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: sync-upload.sh [OPTIONS]

Sync a local directory to an S3 prefix.

Options:
  --source PATH         Local source directory (required)
  --bucket NAME         Target bucket (required)
  --prefix PATH         Target prefix inside bucket
  --region REGION       AWS region override
  --profile PROFILE     AWS CLI profile
  --delete              Delete remote objects not present locally
  --exclude PATTERN     Exclude pattern (repeatable)
  --include PATTERN     Include pattern (repeatable)
  --storage-class CLASS Storage class for uploaded objects
  --sse MODE            Server-side encryption mode (AES256|aws:kms)
  --sse-kms-key-id ID   KMS key ID/ARN (requires --sse aws:kms)
  --exact-timestamps    Compare timestamps exactly
  --no-progress         Disable transfer progress output
  --dry-run             Print planned command only
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [sync-upload] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_bucket_name() {
  local name="$1"
  [[ ${#name} -ge 3 && ${#name} -le 63 ]] || return 1
  [[ "$name" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]] || return 1
}

normalize_prefix() {
  local p="$1"
  p="${p#/}"
  p="${p%/}"
  printf '%s' "$p"
}

source_dir=""
bucket_name=""
prefix=""
region=""
profile=""
delete_extra=false
exact_timestamps=false
no_progress=false
dry_run=false
storage_class=""
sse_mode=""
sse_kms_key_id=""
exclude_patterns=()
include_patterns=()

while (($#)); do
  case "$1" in
    --source)
      shift
      (($#)) || die "--source requires a value"
      source_dir="$1"
      ;;
    --bucket)
      shift
      (($#)) || die "--bucket requires a value"
      validate_bucket_name "$1" || die "invalid bucket name: $1"
      bucket_name="$1"
      ;;
    --prefix)
      shift
      (($#)) || die "--prefix requires a value"
      prefix="$(normalize_prefix "$1")"
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
    --delete)
      delete_extra=true
      ;;
    --exclude)
      shift
      (($#)) || die "--exclude requires a value"
      exclude_patterns+=("$1")
      ;;
    --include)
      shift
      (($#)) || die "--include requires a value"
      include_patterns+=("$1")
      ;;
    --storage-class)
      shift
      (($#)) || die "--storage-class requires a value"
      storage_class="$1"
      ;;
    --sse)
      shift
      (($#)) || die "--sse requires a value"
      case "$1" in
        AES256 | aws:kms) sse_mode="$1" ;;
        *) die "invalid --sse value: $1 (expected AES256|aws:kms)" ;;
      esac
      ;;
    --sse-kms-key-id)
      shift
      (($#)) || die "--sse-kms-key-id requires a value"
      sse_kms_key_id="$1"
      ;;
    --exact-timestamps)
      exact_timestamps=true
      ;;
    --no-progress)
      no_progress=true
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

[[ -n "$source_dir" ]] || die "--source is required"
[[ -n "$bucket_name" ]] || die "--bucket is required"
[[ -d "$source_dir" ]] || die "source directory not found: $source_dir"
command_exists aws || die "aws CLI is required but not found"

if [[ -n "$sse_kms_key_id" && "$sse_mode" != "aws:kms" ]]; then
  die "--sse-kms-key-id requires --sse aws:kms"
fi

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

target_uri="s3://$bucket_name"
[[ -n "$prefix" ]] && target_uri+="/$prefix"

sync_cmd=(aws "${aws_options[@]}" s3 sync "$source_dir" "$target_uri")
$delete_extra && sync_cmd+=(--delete)
$exact_timestamps && sync_cmd+=(--exact-timestamps)
$no_progress && sync_cmd+=(--no-progress)
[[ -n "$storage_class" ]] && sync_cmd+=(--storage-class "$storage_class")
if [[ -n "$sse_mode" ]]; then
  sync_cmd+=(--sse "$sse_mode")
  [[ -n "$sse_kms_key_id" ]] && sync_cmd+=(--sse-kms-key-id "$sse_kms_key_id")
fi
for pat in "${exclude_patterns[@]}"; do
  sync_cmd+=(--exclude "$pat")
done
for pat in "${include_patterns[@]}"; do
  sync_cmd+=(--include "$pat")
done
$dry_run && sync_cmd+=(--dryrun)

printf '%s [sync-upload] executing sync to %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$target_uri" >&2
"${sync_cmd[@]}"

log "sync upload completed"
exit 0
