#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: backup.sh [OPTIONS]

Create a PostgreSQL backup using pg_dump.

Options:
  --host HOST              PostgreSQL host (default: localhost)
  --port PORT              PostgreSQL port (default: 5432)
  --user USER              Database user (required)
  --database NAME          Database name (required)
  --output-file PATH       Backup output file (required)
  --format FORMAT          custom|plain (default: custom)
  --compress-level N       Compression level 0..9 for custom format (default: 6)
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
port=5432
db_user=""
database=""
output_file=""
backup_format="custom"
compress_level=6
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
    --format)
      shift
      (($#)) || die "--format requires a value"
      case "$1" in
        custom | plain) backup_format="$1" ;;
        *) die "invalid --format value: $1" ;;
      esac
      ;;
    --compress-level)
      shift
      (($#)) || die "--compress-level requires a value"
      [[ "$1" =~ ^[0-9]$ ]] || die "--compress-level must be in range 0..9"
      compress_level="$1"
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

command_exists pg_dump || die "pg_dump is required but not found"
[[ -n "$db_user" ]] || die "--user is required"
[[ -n "$database" ]] || die "--database is required"
[[ -n "$output_file" ]] || die "--output-file is required"

cmd=(pg_dump --host "$host" --port "$port" --username "$db_user" --file "$output_file")

case "$backup_format" in
  custom)
    cmd+=(--format custom --compress "$compress_level")
    ;;
  plain)
    cmd+=(--format plain)
    ;;
esac

cmd+=("$database")
run_cmd "${cmd[@]}"
