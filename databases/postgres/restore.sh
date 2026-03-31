#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: restore.sh [OPTIONS]

Restore a PostgreSQL backup from plain SQL or custom archive format.

Options:
  --host HOST              PostgreSQL host (default: localhost)
  --port PORT              PostgreSQL port (default: 5432)
  --user USER              Database user (required)
  --database NAME          Target database (required)
  --input-file PATH        Backup input file (required)
  --format FORMAT          auto|custom|plain (default: auto)
  --clean                  Drop database objects before recreate
  --create                 Include database create statements where supported
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

detect_format() {
  case "$1" in
    *.sql) printf 'plain' ;;
    *.dump | *.backup | *.pgdump) printf 'custom' ;;
    *) printf 'custom' ;;
  esac
}

host="localhost"
port=5432
db_user=""
database=""
input_file=""
restore_format="auto"
clean=false
create_db=false
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
    --format)
      shift
      (($#)) || die "--format requires a value"
      case "$1" in
        auto | custom | plain) restore_format="$1" ;;
        *) die "invalid --format value: $1" ;;
      esac
      ;;
    --clean)
      clean=true
      ;;
    --create)
      create_db=true
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

command_exists psql || die "psql is required but not found"
command_exists pg_restore || die "pg_restore is required but not found"
[[ -n "$db_user" ]] || die "--user is required"
[[ -n "$database" ]] || die "--database is required"
[[ -n "$input_file" ]] || die "--input-file is required"
[[ -f "$input_file" ]] || die "input file not found: $input_file"

if [[ "$restore_format" == "auto" ]]; then
  restore_format="$(detect_format "$input_file")"
fi

if [[ "$restore_format" == "plain" ]]; then
  cmd=(psql --host "$host" --port "$port" --username "$db_user" --dbname "$database" --file "$input_file")
  run_cmd "${cmd[@]}"
  exit 0
fi

cmd=(pg_restore --host "$host" --port "$port" --username "$db_user" --dbname "$database")
$clean && cmd+=(--clean)
$create_db && cmd+=(--create)
cmd+=("$input_file")

run_cmd "${cmd[@]}"
