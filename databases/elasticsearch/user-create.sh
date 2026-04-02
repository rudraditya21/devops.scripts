#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: user-create.sh [OPTIONS]

Create a elasticsearch user specification.

Options:
  --username NAME          Username to create (required)
  --role NAME              Role/profile name (required)
  --password-env NAME      Env var holding password (default: DB_PASSWORD)
  --output-file PATH       Output manifest path (required)
  --dry-run                Print actions without writing file
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

username=""
role=""
password_env="DB_PASSWORD"
output_file=""
dry_run=false

while (($#)); do
  case "$1" in
    --username) shift; (($#)) || die "--username requires a value"; username="$1" ;;
    --role) shift; (($#)) || die "--role requires a value"; role="$1" ;;
    --password-env) shift; (($#)) || die "--password-env requires a value"; password_env="$1" ;;
    --output-file) shift; (($#)) || die "--output-file requires a value"; output_file="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$username" ]] || die "--username is required"
[[ -n "$role" ]] || die "--role is required"
[[ -n "$output_file" ]] || die "--output-file is required"

if $dry_run; then
  printf 'DRY-RUN: create user spec %s (%s) -> %s\n' "$username" "$role" "$output_file"
  exit 0
fi

mkdir -p "$(dirname "$output_file")"
cat > "$output_file" <<USER_SPEC
engine=elasticsearch
username=$username
role=$role
password_env=$password_env
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
USER_SPEC

printf 'User specification written to %s\n' "$output_file"
exit 0
