#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: rotate-password.sh [OPTIONS]

Rotate redis credential metadata.

Options:
  --secret-file PATH       Secret metadata path (required)
  --new-version VALUE      New secret version label (required)
  --dry-run                Print actions without writing file
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

secret_file=""
new_version=""
dry_run=false

while (($#)); do
  case "$1" in
    --secret-file) shift; (($#)) || die "--secret-file requires a value"; secret_file="$1" ;;
    --new-version) shift; (($#)) || die "--new-version requires a value"; new_version="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$secret_file" ]] || die "--secret-file is required"
[[ -n "$new_version" ]] || die "--new-version is required"

if $dry_run; then
  printf 'DRY-RUN: rotate redis secret metadata to version %s\n' "$new_version"
  exit 0
fi

mkdir -p "$(dirname "$secret_file")"
cat > "$secret_file" <<SECRET_META
engine=redis
version=$new_version
rotated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SECRET_META

printf 'Rotated secret metadata written to %s\n' "$secret_file"
exit 0
