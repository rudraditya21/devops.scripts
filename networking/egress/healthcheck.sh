#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: healthcheck.sh [OPTIONS]

Run a basic healthcheck for egress networking workflows.

Options:
  --endpoint HOST      Optional endpoint label/host
  --strict             Treat WARN as failure
  --json               Emit JSON output
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() { local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

endpoint=""
strict=false
json=false

while (($#)); do
  case "$1" in
    --endpoint) shift; (($#)) || die "--endpoint requires a value"; endpoint="$1" ;;
    --strict) strict=true ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

cmd_status="PASS"
cmd_detail="bash available"
if ! command -v bash > /dev/null 2>&1; then
  cmd_status="FAIL"
  cmd_detail="bash not found"
fi

endpoint_status="SKIP"
endpoint_detail="no endpoint provided"
if [[ -n "$endpoint" ]]; then
  endpoint_status="PASS"
  endpoint_detail="endpoint value accepted"
fi

overall="PASS"
if [[ "$cmd_status" == "FAIL" ]]; then
  overall="FAIL"
elif [[ "$endpoint_status" == "SKIP" && "$strict" == true ]]; then
  overall="FAIL"
fi

if $json; then
  printf '{"domain":"egress","overall":"%s","checks":[{"name":"cmd:bash","status":"%s","detail":"%s"},{"name":"endpoint","status":"%s","detail":"%s"}]}\n' \
    "$(json_escape "$overall")" \
    "$(json_escape "$cmd_status")" \
    "$(json_escape "$cmd_detail")" \
    "$(json_escape "$endpoint_status")" \
    "$(json_escape "$endpoint_detail")"
else
  printf 'domain: egress\n'
  printf 'overall: %s\n' "$overall"
  printf 'checks:\n'
  printf '  - cmd:bash => %s (%s)\n' "$cmd_status" "$cmd_detail"
  printf '  - endpoint => %s (%s)\n' "$endpoint_status" "$endpoint_detail"
fi

[[ "$overall" == "PASS" ]] || exit 1
exit 0
