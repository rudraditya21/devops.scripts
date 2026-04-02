#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: backup.sh [OPTIONS]

Create a mongodb backup artifact.

Options:
  --database NAME          Database/service name (required)
  --destination PATH       Backup artifact path (required)
  --retention-days N       Retention in days (default: 7)
  --compress               Enable compression (default)
  --no-compress            Disable compression
  --dry-run                Print actions without writing files
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

name=""
destination=""
retention_days="7"
compress=true
dry_run=false

while (($#)); do
  case "$1" in
    --database) shift; (($#)) || die "--database requires a value"; name="$1" ;;
    --destination) shift; (($#)) || die "--destination requires a value"; destination="$1" ;;
    --retention-days) shift; (($#)) || die "--retention-days requires a value"; retention_days="$1" ;;
    --compress) compress=true ;;
    --no-compress) compress=false ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$name" ]] || die "--database is required"
[[ -n "$destination" ]] || die "--destination is required"
[[ "$retention_days" =~ ^[0-9]+$ ]] || die "--retention-days must be numeric"

if $dry_run; then
  printf 'DRY-RUN: create backup for %s at %s (retention=%sd compress=%s)\n' "$name" "$destination" "$retention_days" "$compress"
  exit 0
fi

mkdir -p "$(dirname "$destination")"
cat > "$destination" <<MANIFEST
engine=mongodb
database=$name
retention_days=$retention_days
compressed=$compress
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
MANIFEST

printf 'Backup metadata written to %s\n' "$destination"
exit 0
