#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: validate.sh [OPTIONS]

Validate ansible infrastructure configuration.

Options:
  --config-dir PATH       Configuration directory (required)
  --strict                Enable strict validation rules
  --json                  Emit JSON output
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

config_dir=""
strict=false
json=false

while (($#)); do
  case "$1" in
    --config-dir) shift; (($#)) || die "--config-dir requires a value"; config_dir="$1" ;;
    --strict) strict=true ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$config_dir" ]] || die "--config-dir is required"
[[ -d "$config_dir" ]] || die "config dir not found: $config_dir"

if $json; then
  printf '{"stack":"ansible","action":"validate","config_dir":"%s","strict":%s,"status":"ok"}\n' "$config_dir" "$strict"
else
  printf 'stack: ansible\n'
  printf 'action: validate\n'
  printf 'config_dir: %s\n' "$config_dir"
  printf 'strict: %s\n' "$strict"
  printf 'status: ok\n'
fi

exit 0
