#!/usr/bin/env bash
set -euo pipefail

usage(){ cat << 'USAGE'
Usage: cleanup.sh [OPTIONS]

Clean database backup artifacts from a directory.

Options:
  --backup-dir DIR       Backup dir to prune (default: ~/backups)
  --days N               Remove backup files older than N days (default: 30)
  --dry-run              Print actions without executing
  -h, --help             Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
run_cmd(){ if $dry_run; then printf 'DRY-RUN:' >&2; printf ' %q' "$@" >&2; printf '\n' >&2; return 0; fi; "$@"; }

backup_dir="$HOME/backups"
days=30
dry_run=false

while (($#)); do
  case "$1" in
    --backup-dir) shift; (($#)) || die "--backup-dir requires a value"; backup_dir="$1" ;;
    --days) shift; (($#)) || die "--days requires a value"; [[ "$1" =~ ^[0-9]+$ ]] || die "--days must be non-negative integer"; days="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -d "$backup_dir" ]] || exit 0
if $dry_run; then
  run_cmd find "$backup_dir" -type f \( -name '*.sql' -o -name '*.dump' -o -name '*.backup' -o -name '*.gz' \) -mtime "+$days" -print
else
  find "$backup_dir" -type f \( -name '*.sql' -o -name '*.dump' -o -name '*.backup' -o -name '*.gz' \) -mtime "+$days" -delete
fi

exit 0
