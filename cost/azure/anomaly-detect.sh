#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: anomaly-detect.sh [OPTIONS]

Detect azure spend anomalies from baseline and current values.

Options:
  --baseline AMOUNT        Baseline expected spend (required)
  --current AMOUNT         Current observed spend (required)
  --threshold-percent N    Deviation threshold percent (default: 30)
  --json                   Emit JSON output
  --fail-on-anomaly        Exit non-zero if anomaly is detected
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

is_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

baseline=""
current=""
threshold="30"
json=false
fail_on_anomaly=false

while (($#)); do
  case "$1" in
    --baseline) shift; (($#)) || die "--baseline requires a value"; baseline="$1" ;;
    --current) shift; (($#)) || die "--current requires a value"; current="$1" ;;
    --threshold-percent) shift; (($#)) || die "--threshold-percent requires a value"; threshold="$1" ;;
    --json) json=true ;;
    --fail-on-anomaly) fail_on_anomaly=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$baseline" ]] || die "--baseline is required"
[[ -n "$current" ]] || die "--current is required"
is_number "$baseline" || die "--baseline must be numeric"
is_number "$current" || die "--current must be numeric"
is_number "$threshold" || die "--threshold-percent must be numeric"

if awk -v b="$baseline" 'BEGIN { exit !(b == 0) }'; then
  deviation_percent=$(awk -v c="$current" 'BEGIN { if (c > 0) print 100; else print 0 }')
else
  deviation_percent=$(awk -v c="$current" -v b="$baseline" 'BEGIN { printf "%.2f", ((c - b) / b) * 100 }')
fi

status="NORMAL"
if awk -v d="$deviation_percent" -v t="$threshold" 'BEGIN { exit !(d > t) }'; then
  status="ANOMALY"
fi

if $json; then
  printf '{"provider":"azure","baseline":%s,"current":%s,"deviation_percent":%s,"threshold_percent":%s,"status":"%s"}\n' \
    "$baseline" "$current" "$deviation_percent" "$threshold" "$status"
else
  printf 'provider: azure\n'
  printf 'baseline: %s\n' "$baseline"
  printf 'current: %s\n' "$current"
  printf 'deviation_percent: %s\n' "$deviation_percent"
  printf 'threshold_percent: %s\n' "$threshold"
  printf 'status: %s\n' "$status"
fi

if $fail_on_anomaly && [[ "$status" == "ANOMALY" ]]; then
  exit 1
fi

exit 0
