#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: schema-diff.sh [OPTIONS]

Compare two sqlserver schema snapshots.

Options:
  --current PATH           Current schema file (required)
  --desired PATH           Desired schema file (required)
  --format FMT             table|json (default: table)
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

current=""
desired=""
format="table"

while (($#)); do
  case "$1" in
    --current) shift; (($#)) || die "--current requires a value"; current="$1" ;;
    --desired) shift; (($#)) || die "--desired requires a value"; desired="$1" ;;
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$current" ]] || die "--current is required"
[[ -n "$desired" ]] || die "--desired is required"
[[ -f "$current" ]] || die "current file not found: $current"
[[ -f "$desired" ]] || die "desired file not found: $desired"
case "$format" in table|json) ;; *) die "--format must be table or json" ;; esac

diff_output="$(diff -u "$current" "$desired" || true)"
changed=false
[[ -n "$diff_output" ]] && changed=true
line_count=$(printf '%s' "$diff_output" | grep -c '^[+-]' || true)

if [[ "$format" == "json" ]]; then
  printf '{"engine":"sqlserver","changed":%s,"line_changes":%s,"summary":"%s"}\n' \
    "$changed" "$line_count" "$(json_escape "$diff_output")"
else
  printf 'engine: sqlserver\n'
  printf 'changed: %s\n' "$changed"
  printf 'line_changes: %s\n' "$line_count"
  if [[ -n "$diff_output" ]]; then
    printf '%s\n' "$diff_output"
  fi
fi

exit 0
