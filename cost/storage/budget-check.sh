#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: budget-check.sh [OPTIONS]

Evaluate storage spend against a budget threshold.

Options:
  --budget-limit AMOUNT   Budget limit (required)
  --current-spend AMOUNT  Current spend (required)
  --warn-percent N        Warn threshold percent (default: 80)
  --json                  Emit JSON output
  --fail-on-breach        Exit non-zero when budget is breached
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

is_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

budget_limit=""
current_spend=""
warn_percent="80"
json=false
fail_on_breach=false

while (($#)); do
  case "$1" in
    --budget-limit) shift; (($#)) || die "--budget-limit requires a value"; budget_limit="$1" ;;
    --current-spend) shift; (($#)) || die "--current-spend requires a value"; current_spend="$1" ;;
    --warn-percent) shift; (($#)) || die "--warn-percent requires a value"; warn_percent="$1" ;;
    --json) json=true ;;
    --fail-on-breach) fail_on_breach=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$budget_limit" ]] || die "--budget-limit is required"
[[ -n "$current_spend" ]] || die "--current-spend is required"
is_number "$budget_limit" || die "--budget-limit must be numeric"
is_number "$current_spend" || die "--current-spend must be numeric"
[[ "$warn_percent" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--warn-percent must be numeric"

utilization=$(awk -v c="$current_spend" -v b="$budget_limit" 'BEGIN { if (b == 0) print 0; else printf "%.2f", (c / b) * 100 }')
status="OK"
if awk -v c="$current_spend" -v b="$budget_limit" 'BEGIN { exit !(c > b) }'; then
  status="BREACH"
elif awk -v u="$utilization" -v w="$warn_percent" 'BEGIN { exit !(u >= w) }'; then
  status="WARN"
fi

if $json; then
  printf '{"provider":"storage","budget_limit":%s,"current_spend":%s,"utilization_percent":%s,"status":"%s"}\n' \
    "$budget_limit" "$current_spend" "$utilization" "$(json_escape "$status")"
else
  printf 'provider: storage\n'
  printf 'budget_limit: %s\n' "$budget_limit"
  printf 'current_spend: %s\n' "$current_spend"
  printf 'utilization_percent: %s\n' "$utilization"
  printf 'status: %s\n' "$status"
fi

if $fail_on_breach && [[ "$status" == "BREACH" ]]; then
  exit 1
fi

exit 0
