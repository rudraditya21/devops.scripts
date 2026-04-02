#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: generate.sh [OPTIONS]

Generate error-budget SRE artifacts.

Options:
  --service NAME       Service name (required)
  --window LABEL       Time window label (default: current)
  --output PATH        Output file path
  --json               Emit JSON output
  --dry-run            Print actions without executing
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() { local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

service=""
window="current"
output_path=""
json=false
dry_run=false

while (($#)); do
  case "$1" in
    --service) shift; (($#)) || die "--service requires a value"; service="$1" ;;
    --window) shift; (($#)) || die "--window requires a value"; window="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output_path="$1" ;;
    --json) json=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$service" ]] || die "--service is required"

payload_text=$(cat <<TXT
kind: error-budget
service: $service
window: $window
generated_at: $(date +%Y-%m-%dT%H:%M:%S%z)
TXT
)

if $json; then
  payload=$(printf '{"kind":"error-budget","service":"%s","window":"%s","generated_at":"%s"}' \
    "$(json_escape "$service")" \
    "$(json_escape "$window")" \
    "$(date +%Y-%m-%dT%H:%M:%S%z)")
else
  payload="$payload_text"
fi

if [[ -n "$output_path" ]]; then
  if $dry_run; then
    printf 'DRY-RUN: would write error-budget artifact to %s\n' "$output_path" >&2
  else
    mkdir -p "$(dirname "$output_path")"
    printf '%s\n' "$payload" > "$output_path"
  fi
else
  printf '%s\n' "$payload"
fi

exit 0
