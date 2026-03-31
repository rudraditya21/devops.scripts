#!/usr/bin/env bash
set -euo pipefail

usage(){ cat << 'USAGE'
Usage: cleanup.sh [OPTIONS]

Clean temporary security artifacts from a target directory.

Options:
  --temp-dir DIR         Temp directory to clean (default: /tmp)
  --days N               Remove files older than N days (default: 7)
  --dry-run              Print actions without executing
  -h, --help             Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
run_cmd(){ if $dry_run; then printf 'DRY-RUN:' >&2; printf ' %q' "$@" >&2; printf '\n' >&2; return 0; fi; "$@"; }

temp_dir="/tmp"
days=7
dry_run=false

while (($#)); do
  case "$1" in
    --temp-dir) shift; (($#)) || die "--temp-dir requires a value"; temp_dir="$1" ;;
    --days) shift; (($#)) || die "--days requires a value"; [[ "$1" =~ ^[0-9]+$ ]] || die "--days must be non-negative integer"; days="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -d "$temp_dir" ]] || exit 0
if $dry_run; then
  run_cmd find "$temp_dir" -type f \( -name '*.pem' -o -name '*.key' -o -name '*.csr' -o -name '*.asc' -o -name 'id_*' \) -mtime "+$days" -print
else
  find "$temp_dir" -type f \( -name '*.pem' -o -name '*.key' -o -name '*.csr' -o -name '*.asc' -o -name 'id_*' \) -mtime "+$days" -delete
fi

exit 0
