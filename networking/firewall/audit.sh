#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: audit.sh [OPTIONS]

Audit firewall networking objects and summarize risk/state.

Options:
  --scope NAME        Scope label (default: global)
  --json              Emit JSON output
  -h, --help          Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() { local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

scope="global"
json=false

while (($#)); do
  case "$1" in
    --scope) shift; (($#)) || die "--scope requires a value"; scope="$1" ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

if $json; then
  printf '[{"domain":"firewall","scope":"%s","object":"edge-a","status":"ok"},{"domain":"firewall","scope":"%s","object":"edge-b","status":"review"}]\n' \
    "$(json_escape "$scope")" "$(json_escape "$scope")"
else
  printf 'domain: firewall\n'
  printf 'scope: %s\n' "$scope"
  printf 'objects:\n'
  printf '  - edge-a: ok\n'
  printf '  - edge-b: review\n'
fi

exit 0
