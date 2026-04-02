#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: report.sh [OPTIONS]

Generate a kubernetes cost report snapshot.

Options:
  --start-date YYYY-MM-DD   Report window start date
  --end-date YYYY-MM-DD     Report window end date
  --estimated-total AMOUNT  Estimated total spend for the period
  --currency CODE           Currency code (default: USD)
  --scope NAME              Scope label (default: global)
  --format FMT              table|json (default: table)
  --output PATH             Write report to file instead of stdout
  --dry-run                 Print actions without executing
  -h, --help                Show help
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
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

start_date=""
end_date=""
estimated_total=""
currency="USD"
scope="global"
format="table"
output_path=""
dry_run=false

while (($#)); do
  case "$1" in
    --start-date) shift; (($#)) || die "--start-date requires a value"; start_date="$1" ;;
    --end-date) shift; (($#)) || die "--end-date requires a value"; end_date="$1" ;;
    --estimated-total) shift; (($#)) || die "--estimated-total requires a value"; estimated_total="$1" ;;
    --currency) shift; (($#)) || die "--currency requires a value"; currency="$1" ;;
    --scope) shift; (($#)) || die "--scope requires a value"; scope="$1" ;;
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output_path="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -z "$estimated_total" ]] || is_number "$estimated_total" || die "--estimated-total must be numeric"
case "$format" in table|json) ;; *) die "--format must be table or json" ;; esac

if [[ -z "$start_date" ]]; then start_date="$(date +%Y-%m-01)"; fi
if [[ -z "$end_date" ]]; then end_date="$(date +%Y-%m-%d)"; fi
if [[ -z "$estimated_total" ]]; then estimated_total="0"; fi

if [[ "$format" == "json" ]]; then
  report_content=$(printf '{"provider":"kubernetes","scope":"%s","start_date":"%s","end_date":"%s","estimated_total":%s,"currency":"%s"}\n' \
    "$(json_escape "$scope")" \
    "$(json_escape "$start_date")" \
    "$(json_escape "$end_date")" \
    "$estimated_total" \
    "$(json_escape "$currency")")
else
  report_content=$(cat <<TABLE
provider: kubernetes
scope: $scope
period_start: $start_date
period_end: $end_date
estimated_total: $estimated_total $currency
TABLE
)
fi

if [[ -n "$output_path" ]]; then
  if $dry_run; then
    printf 'DRY-RUN: write report to %s\n' "$output_path" >&2
  else
    mkdir -p "$(dirname "$output_path")"
    printf '%s\n' "$report_content" > "$output_path"
  fi
else
  printf '%s\n' "$report_content"
fi

exit 0
