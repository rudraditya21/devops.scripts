#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: cleanup.sh [OPTIONS]

Clean stale hook artifacts from a path.

Options:
  --path DIR          Directory to clean (default: .git)
  --days N            Remove files older than N days (default: 30)
  --pattern GLOB      Filename glob (default: *)
  --dry-run           Print matches without deleting
  -h, --help          Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }

path=".git"
days="30"
pattern="*"
dry_run=false

while (($#)); do
  case "$1" in
    --path) shift; (($#)) || die "--path requires a value"; path="$1" ;;
    --days) shift; (($#)) || die "--days requires a value"; [[ "$1" =~ ^[0-9]+$ ]] || die "--days must be non-negative integer"; days="$1" ;;
    --pattern) shift; (($#)) || die "--pattern requires a value"; pattern="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -d "$path" ]] || exit 0

if $dry_run; then
  find "$path" -type f -name "$pattern" -mtime "+$days" -print
else
  find "$path" -type f -name "$pattern" -mtime "+$days" -delete
fi

exit 0
