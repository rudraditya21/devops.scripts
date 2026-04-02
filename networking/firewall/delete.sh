#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: delete.sh [OPTIONS]

Run delete for firewall networking objects.

Options:
  --name NAME         Object name (required)
  --target VALUE      Target resource/group/endpoint
  --cidr CIDR         CIDR range value
  --json              Emit JSON output
  --dry-run           Print actions without executing
  -h, --help          Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() { local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

name=""
target=""
cidr=""
json=false
dry_run=false

while (($#)); do
  case "$1" in
    --name) shift; (($#)) || die "--name requires a value"; name="$1" ;;
    --target) shift; (($#)) || die "--target requires a value"; target="$1" ;;
    --cidr) shift; (($#)) || die "--cidr requires a value"; cidr="$1" ;;
    --json) json=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$name" ]] || die "--name is required"

if $json; then
  printf '{"domain":"firewall","action":"delete","name":"%s","target":"%s","cidr":"%s","dry_run":%s}\n' \
    "$(json_escape "$name")" \
    "$(json_escape "$target")" \
    "$(json_escape "$cidr")" \
    "$dry_run"
else
  printf 'domain: firewall\n'
  printf 'action: delete\n'
  printf 'name: %s\n' "$name"
  [[ -n "$target" ]] && printf 'target: %s\n' "$target"
  [[ -n "$cidr" ]] && printf 'cidr: %s\n' "$cidr"
  printf 'dry_run: %s\n' "$dry_run"
fi

if $dry_run; then
  printf 'DRY-RUN: would delete firewall object %s\n' "$name" >&2
fi

exit 0
