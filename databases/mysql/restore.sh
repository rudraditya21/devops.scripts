#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: restore.sh [OPTIONS]

Restore a MySQL backup from SQL file.

Options:
  --host HOST              MySQL host (default: localhost)
  --port PORT              MySQL port (default: 3306)
  --user USER              Database user (required)
  --database NAME          Target database (required)
  --input-file PATH        SQL input file (required)
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

host="localhost"
port=3306
db_user=""
database=""
input_file=""
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
    --input-file)
      shift
      (($#)) || die "--input-file requires a value"
      input_file="$1"
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

command_exists mysql || die "mysql client is required but not found"
[[ -n "$db_user" ]] || die "--user is required"
[[ -n "$database" ]] || die "--database is required"
[[ -n "$input_file" ]] || die "--input-file is required"
[[ -f "$input_file" ]] || die "input file not found: $input_file"

cmd=(mysql --host "$host" --port "$port" --user "$db_user" "$database")

if $dry_run; then
  printf 'DRY-RUN:' >&2
  printf ' %q' "${cmd[@]}" >&2
  printf ' < %q\n' "$input_file" >&2
  exit 0
fi

"${cmd[@]}" < "$input_file"
