#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: healthcheck.sh [OPTIONS]

Run health checks for error-budget SRE workflows.

Options:
  --strict             Treat WARN/SKIP as failure
  --json               Emit JSON output
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() { local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

strict=false
json=false

while (($#)); do
  case "$1" in
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

file_status="WARN"
file_detail="no local cache artifact present"
if [[ -f "./.sre/error-budget.state" ]]; then
  file_status="PASS"
  file_detail="state file present"
fi

overall="PASS"
if [[ "$cmd_status" == "FAIL" ]]; then
  overall="FAIL"
elif [[ "$strict" == true && "$file_status" != "PASS" ]]; then
  overall="FAIL"
fi

if $json; then
  printf '{"kind":"error-budget","overall":"%s","checks":[{"name":"cmd:bash","status":"%s","detail":"%s"},{"name":"state-file","status":"%s","detail":"%s"}]}' \
    "$(json_escape "$overall")" \
    "$(json_escape "$cmd_status")" \
    "$(json_escape "$cmd_detail")" \
    "$(json_escape "$file_status")" \
    "$(json_escape "$file_detail")"
  printf '\n'
else
  printf 'kind: error-budget\n'
  printf 'overall: %s\n' "$overall"
  printf 'checks:\n'
  printf '  - cmd:bash => %s (%s)\n' "$cmd_status" "$cmd_detail"
  printf '  - state-file => %s (%s)\n' "$file_status" "$file_detail"
fi

[[ "$overall" == "PASS" ]] || exit 1
exit 0
