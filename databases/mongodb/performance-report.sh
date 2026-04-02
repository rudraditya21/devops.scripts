#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: performance-report.sh [OPTIONS]

Generate mongodb performance summary.

Options:
  --window LABEL           Reporting window label (default: 1h)
  --qps N                  Throughput qps (required)
  --p95-ms N               p95 latency in ms (required)
  --error-rate N           Error rate percent (default: 0)
  --format FMT             table|json (default: table)
  --output PATH            Write report to file
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

window="1h"
qps=""
p95_ms=""
error_rate="0"
format="table"
output=""

while (($#)); do
  case "$1" in
    --window) shift; (($#)) || die "--window requires a value"; window="$1" ;;
    --qps) shift; (($#)) || die "--qps requires a value"; qps="$1" ;;
    --p95-ms) shift; (($#)) || die "--p95-ms requires a value"; p95_ms="$1" ;;
    --error-rate) shift; (($#)) || die "--error-rate requires a value"; error_rate="$1" ;;
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$qps" ]] || die "--qps is required"
[[ -n "$p95_ms" ]] || die "--p95-ms is required"
[[ "$qps" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--qps must be numeric"
[[ "$p95_ms" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--p95-ms must be numeric"
[[ "$error_rate" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--error-rate must be numeric"
case "$format" in table|json) ;; *) die "--format must be table or json" ;; esac

score=$(awk -v q="$qps" -v l="$p95_ms" -v e="$error_rate" 'BEGIN { s=q-(l*0.5)-(e*10); if (s<0) s=0; printf "%.2f", s }')

if [[ "$format" == "json" ]]; then
  report=$(printf '{"engine":"mongodb","window":"%s","qps":%s,"p95_ms":%s,"error_rate":%s,"score":%s}\n' \
    "$(json_escape "$window")" "$qps" "$p95_ms" "$error_rate" "$score")
else
  report=$(cat <<TABLE
engine: mongodb
window: $window
qps: $qps
p95_ms: $p95_ms
error_rate: $error_rate
score: $score
TABLE
)
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$report" > "$output"
else
  printf '%s\n' "$report"
fi

exit 0
