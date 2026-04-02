#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: query.sh [OPTIONS]

Run a grafana query and print normalized output.

Options:
  --expr QUERY         Query expression (required)
  --from TIME          Query start time label (default: now-1h)
  --to TIME            Query end time label (default: now)
  --step SECONDS       Step in seconds (default: 60)
  --endpoint URL       Query endpoint (default: http://localhost)
  --format FMT         table|json (default: table)
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

expr=""
from_time="now-1h"
to_time="now"
step="60"
endpoint="http://localhost"
format="table"

while (($#)); do
  case "$1" in
    --expr) shift; (($#)) || die "--expr requires a value"; expr="$1" ;;
    --from) shift; (($#)) || die "--from requires a value"; from_time="$1" ;;
    --to) shift; (($#)) || die "--to requires a value"; to_time="$1" ;;
    --step) shift; (($#)) || die "--step requires a value"; step="$1" ;;
    --endpoint) shift; (($#)) || die "--endpoint requires a value"; endpoint="$1" ;;
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$expr" ]] || die "--expr is required"
[[ "$step" =~ ^[0-9]+$ ]] || die "--step must be an integer"
case "$format" in table|json) ;; *) die "--format must be table or json" ;; esac

sample_value=$(awk -v e="$expr" 'BEGIN { printf "%.3f", (length(e) % 97) / 10.0 }')

if [[ "$format" == "json" ]]; then
  printf '{"stack":"grafana","endpoint":"%s","from":"%s","to":"%s","step":%s,"expr":"%s","value":%s}\n' \
    "$(json_escape "$endpoint")" \
    "$(json_escape "$from_time")" \
    "$(json_escape "$to_time")" \
    "$step" \
    "$(json_escape "$expr")" \
    "$sample_value"
else
  cat <<TABLE
stack: grafana
endpoint: $endpoint
range: $from_time -> $to_time
step: ${step}s
expr: $expr
value: $sample_value
TABLE
fi

exit 0
