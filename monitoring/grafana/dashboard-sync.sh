#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: dashboard-sync.sh [OPTIONS]

Sync grafana dashboard definitions.

Options:
  --source PATH        Source file or directory (required)
  --destination PATH   Destination directory (required)
  --folder NAME        Logical folder name (default: default)
  --dry-run            Print actions only
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

source_path=""
destination_path=""
folder="default"
dry_run=false

while (($#)); do
  case "$1" in
    --source) shift; (($#)) || die "--source requires a value"; source_path="$1" ;;
    --destination) shift; (($#)) || die "--destination requires a value"; destination_path="$1" ;;
    --folder) shift; (($#)) || die "--folder requires a value"; folder="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$source_path" ]] || die "--source is required"
[[ -n "$destination_path" ]] || die "--destination is required"
[[ -e "$source_path" ]] || die "--source path not found: $source_path"

if $dry_run; then
  printf 'DRY-RUN: sync dashboards %s -> %s (folder=%s)\n' "$source_path" "$destination_path" "$folder"
  exit 0
fi

mkdir -p "$destination_path"
if [[ -d "$source_path" ]]; then
  cp -R "$source_path"/. "$destination_path"/
else
  cp "$source_path" "$destination_path"/
fi

printf 'Synced grafana dashboards to %s (folder=%s)\n' "$destination_path" "$folder"
exit 0
