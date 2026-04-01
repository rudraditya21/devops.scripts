#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: retention-cleanup.sh [OPTIONS]

Delete expired object-storage backup artifacts based on retention policy.

Options:
  --backup-dir DIR     Backup directory to prune (default: ./backups/object-storage)
  --days N             Retention window in days (default: 30)
  --pattern GLOB       File glob pattern (default: *)
  --dry-run            Print candidate files without deleting
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

backup_dir="./backups/object-storage"
days="30"
pattern="*"
dry_run=false

while (($#)); do
  case "$1" in
    --backup-dir) shift; (($#)) || die "--backup-dir requires a value"; backup_dir="$1" ;;
    --days) shift; (($#)) || die "--days requires a value"; [[ "$1" =~ ^[0-9]+$ ]] || die "--days must be a non-negative integer"; days="$1" ;;
    --pattern) shift; (($#)) || die "--pattern requires a value"; pattern="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -d "$backup_dir" ]] || exit 0

if $dry_run; then
  find "$backup_dir" -type f -name "$pattern" -mtime "+$days" -print
else
  find "$backup_dir" -type f -name "$pattern" -mtime "+$days" -delete
fi

exit 0
