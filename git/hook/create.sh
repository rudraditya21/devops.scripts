#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create.sh [OPTIONS]

Create hook metadata/object scaffolding.

Options:
  --name NAME         Name/identifier to create (required)
  --metadata KV       Metadata key=value pair (repeatable)
  --json              Emit JSON output
  --dry-run           Print actions without executing
  -h, --help          Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape(){ local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

name=""
metadata=()
json=false
dry_run=false

while (($#)); do
  case "$1" in
    --name) shift; (($#)) || die "--name requires a value"; name="$1" ;;
    --metadata) shift; (($#)) || die "--metadata requires a value"; metadata+=("$1") ;;
    --json) json=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$name" ]] || die "--name is required"

if $json; then
  printf '{"domain":"hook","action":"create","name":"%s","metadata_count":%s,"dry_run":%s}\n' \
    "$(json_escape "$name")" "${#metadata[@]}" "$dry_run"
else
  printf 'domain: hook\n'
  printf 'action: create\n'
  printf 'name: %s\n' "$name"
  printf 'metadata_count: %s\n' "${#metadata[@]}"
  printf 'dry_run: %s\n' "$dry_run"
fi

if $dry_run; then
  printf 'DRY-RUN: would create hook object %s\n' "$name" >&2
fi

exit 0
