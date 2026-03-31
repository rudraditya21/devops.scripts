#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: backup.sh [OPTIONS]

Create a MySQL backup using mysqldump.

Options:
  --host HOST              MySQL host (default: localhost)
  --port PORT              MySQL port (default: 3306)
  --user USER              Database user (required)
  --database NAME          Database name (required)
  --output-file PATH       Backup output file (required)
  --single-transaction     Enable consistent snapshot (default)
  --no-single-transaction  Disable single transaction mode
  --dry-run                Print command without executing
  -h, --help               Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

host="localhost"
port=3306
db_user=""
database=""
output_file=""
single_transaction=true
dry_run=false

while (($#)); do
  case "$1" in
    --host)
      shift
      (($#)) || die "--host requires a value"
      host="$1"
      ;;
    --port)
      shift
      (($#)) || die "--port requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--port must be a positive integer"
      port="$1"
      ;;
    --user)
      shift
      (($#)) || die "--user requires a value"
      db_user="$1"
      ;;
    --database)
      shift
      (($#)) || die "--database requires a value"
      database="$1"
      ;;
    --output-file)
      shift
      (($#)) || die "--output-file requires a value"
      output_file="$1"
      ;;
    --single-transaction)
      single_transaction=true
      ;;
    --no-single-transaction)
      single_transaction=false
      ;;
    --dry-run)
      dry_run=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

command_exists mysqldump || die "mysqldump is required but not found"
[[ -n "$db_user" ]] || die "--user is required"
[[ -n "$database" ]] || die "--database is required"
[[ -n "$output_file" ]] || die "--output-file is required"

cmd=(mysqldump --host "$host" --port "$port" --user "$db_user")
$single_transaction && cmd+=(--single-transaction)
cmd+=("$database")

if $dry_run; then
  printf 'DRY-RUN:' >&2
  printf ' %q' "${cmd[@]}" >&2
  printf ' > %q\n' "$output_file" >&2
  exit 0
fi

"${cmd[@]}" > "$output_file"
