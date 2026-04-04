#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: report.sh [OPTIONS]

Generate waf security report.

Options:
  --input PATH            Source input path (required)
  --format FMT            table|json (default: table)
  --output PATH           Write report to file
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

input=""
format="table"
output=""

while (($#)); do
  case "$1" in
    --input) shift; (($#)) || die "--input requires a value"; input="$1" ;;
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$input" ]] || die "--input is required"
[[ -e "$input" ]] || die "input path not found: $input"
case "$format" in table|json) ;; *) die "--format must be table or json" ;; esac

if [[ "$format" == "json" ]]; then
  report=$(printf '{"domain":"waf","action":"report","input":"%s","status":"ok"}\n' "$(json_escape "$input")")
else
  report=$(cat <<TXT
domain: waf
action: report
input: $input
status: ok
TXT
)
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$report" > "$output"
else
  printf '%s\n' "$report"
fi

exit 0
