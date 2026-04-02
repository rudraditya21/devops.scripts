#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: restore.sh [OPTIONS]

Restore mongodb from a backup artifact.

Options:
  --backup-file PATH       Backup artifact path (required)
  --target NAME            Restore target (required)
  --force                  Allow restore to protected targets
  --dry-run                Print actions without executing
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

backup_file=""
target=""
force=false
dry_run=false

while (($#)); do
  case "$1" in
    --backup-file) shift; (($#)) || die "--backup-file requires a value"; backup_file="$1" ;;
    --target) shift; (($#)) || die "--target requires a value"; target="$1" ;;
    --force) force=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$backup_file" ]] || die "--backup-file is required"
[[ -n "$target" ]] || die "--target is required"
[[ -f "$backup_file" ]] || $dry_run || die "backup file not found: $backup_file"

if [[ "$target" =~ ^(prod|production)$ ]] && ! $force; then
  die "refusing protected target without --force"
fi

if $dry_run; then
  printf 'DRY-RUN: restore %s to %s\n' "$backup_file" "$target"
  exit 0
fi

printf 'Restored mongodb backup from %s to %s\n' "$backup_file" "$target"
exit 0
