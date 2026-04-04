#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: state-backup.sh [OPTIONS]

Back up cloudformation state file.

Options:
  --state-file PATH       State file path (required)
  --destination PATH      Backup destination path (required)
  --dry-run               Print actions without copying
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

state_file=""
destination=""
dry_run=false

while (($#)); do
  case "$1" in
    --state-file) shift; (($#)) || die "--state-file requires a value"; state_file="$1" ;;
    --destination) shift; (($#)) || die "--destination requires a value"; destination="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$state_file" ]] || die "--state-file is required"
[[ -n "$destination" ]] || die "--destination is required"
[[ -f "$state_file" ]] || $dry_run || die "state file not found: $state_file"

if $dry_run; then
  printf 'DRY-RUN: backup cloudformation state %s -> %s\n' "$state_file" "$destination"
  exit 0
fi

mkdir -p "$(dirname "$destination")"
cp "$state_file" "$destination"
printf 'Backed up cloudformation state to %s\n' "$destination"
exit 0
