#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: sync.sh [OPTIONS]

Sync incident SRE metadata between locations.

Options:
  --source PATH        Source path/identifier (required)
  --destination PATH   Destination path/identifier (required)
  --json               Emit JSON output
  --dry-run            Print actions without executing
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape() { local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

source_path=""
dest_path=""
json=false
dry_run=false

while (($#)); do
  case "$1" in
    --source) shift; (($#)) || die "--source requires a value"; source_path="$1" ;;
    --destination) shift; (($#)) || die "--destination requires a value"; dest_path="$1" ;;
    --json) json=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$source_path" ]] || die "--source is required"
[[ -n "$dest_path" ]] || die "--destination is required"

if $json; then
  printf '{"kind":"incident","source":"%s","destination":"%s","dry_run":%s,"status":"ok"}\n' \
    "$(json_escape "$source_path")" \
    "$(json_escape "$dest_path")" \
    "$dry_run"
else
  printf 'kind: incident\n'
  printf 'source: %s\n' "$source_path"
  printf 'destination: %s\n' "$dest_path"
  printf 'dry_run: %s\n' "$dry_run"
  printf 'status: ok\n'
fi

if $dry_run; then
  printf 'DRY-RUN: would sync incident from %s to %s\n' "$source_path" "$dest_path" >&2
fi

exit 0
