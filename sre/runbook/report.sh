#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: report.sh [OPTIONS]

Generate runbook SRE report data.

Options:
  --period LABEL       Report period label (default: 24h)
  --owner NAME         Owner/team label (default: sre)
  --format FMT         table|json (default: table)
  --output PATH        Output file path
  --dry-run            Print actions without executing
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() { local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

period="24h"
owner="sre"
format="table"
output_path=""
dry_run=false

while (($#)); do
  case "$1" in
    --period) shift; (($#)) || die "--period requires a value"; period="$1" ;;
    --owner) shift; (($#)) || die "--owner requires a value"; owner="$1" ;;
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output_path="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

case "$format" in table|json) ;; *) die "--format must be table or json" ;; esac

if [[ "$format" == "json" ]]; then
  payload=$(printf '{"kind":"runbook","period":"%s","owner":"%s","summary":{"ok":3,"warn":1,"critical":0}}' \
    "$(json_escape "$period")" \
    "$(json_escape "$owner")")
else
  payload=$(cat <<TABLE
kind: runbook
period: $period
owner: $owner
summary:
  ok: 3
  warn: 1
  critical: 0
TABLE
)
fi

if [[ -n "$output_path" ]]; then
  if $dry_run; then
    printf 'DRY-RUN: would write runbook report to %s\n' "$output_path" >&2
  else
    mkdir -p "$(dirname "$output_path")"
    printf '%s\n' "$payload" > "$output_path"
  fi
else
  printf '%s\n' "$payload"
fi

exit 0
