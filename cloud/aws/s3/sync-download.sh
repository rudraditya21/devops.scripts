#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: sync-download.sh [OPTIONS]

Sync an S3 bucket/prefix to a local directory.

Options:
  --bucket NAME        Source bucket (required)
  --prefix PATH        Source prefix inside bucket
  --dest PATH          Local destination directory (required)
  --region REGION      AWS region override
  --profile PROFILE    AWS CLI profile
  --delete             Delete local files not present in S3 source
  --exclude PATTERN    Exclude pattern (repeatable)
  --include PATTERN    Include pattern (repeatable)
  --exact-timestamps   Compare timestamps exactly
  --no-progress        Disable transfer progress output
  --dry-run            Print planned command only
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [sync-download] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

bucket_name=""
prefix=""
dest_dir=""
region=""
profile=""
delete_extra=false
exact_timestamps=false
no_progress=false
dry_run=false
exclude_patterns=()
include_patterns=()

while (($#)); do
  case "$1" in
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
    --dest)
      shift
      (($#)) || die "--dest requires a value"
      dest_dir="$1"
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

[[ -n "$bucket_name" ]] || die "--bucket is required"
[[ -n "$dest_dir" ]] || die "--dest is required"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

source_uri="s3://$bucket_name"
[[ -n "$prefix" ]] && source_uri+="/$prefix"

if ! $dry_run; then
  mkdir -p "$dest_dir"
fi

sync_cmd=(aws "${aws_options[@]}" s3 sync "$source_uri" "$dest_dir")
$delete_extra && sync_cmd+=(--delete)
$exact_timestamps && sync_cmd+=(--exact-timestamps)
$no_progress && sync_cmd+=(--no-progress)
for pat in "${exclude_patterns[@]}"; do
  sync_cmd+=(--exclude "$pat")
done
for pat in "${include_patterns[@]}"; do
  sync_cmd+=(--include "$pat")
done
$dry_run && sync_cmd+=(--dryrun)

printf '%s [sync-download] executing sync from %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$source_uri" >&2
"${sync_cmd[@]}"

log "sync download completed"
exit 0
