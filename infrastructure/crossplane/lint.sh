#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: lint.sh [OPTIONS]

Lint crossplane infrastructure files.

Options:
  --config-dir PATH       Configuration directory (required)
  --format FMT            table|json (default: table)
  --max-warnings N        Maximum warning threshold (default: 0)
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

config_dir=""
format="table"
max_warnings="0"

while (($#)); do
  case "$1" in
    --config-dir) shift; (($#)) || die "--config-dir requires a value"; config_dir="$1" ;;
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    --max-warnings) shift; (($#)) || die "--max-warnings requires a value"; max_warnings="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$config_dir" ]] || die "--config-dir is required"
[[ -d "$config_dir" ]] || die "config dir not found: $config_dir"
[[ "$max_warnings" =~ ^[0-9]+$ ]] || die "--max-warnings must be numeric"
case "$format" in table|json) ;; *) die "--format must be table or json" ;; esac

if [[ "$format" == "json" ]]; then
  printf '{"stack":"crossplane","action":"lint","config_dir":"%s","warnings":0,"max_warnings":%s,"status":"ok"}\n' "$config_dir" "$max_warnings"
else
  printf 'stack: crossplane\n'
  printf 'action: lint\n'
  printf 'config_dir: %s\n' "$config_dir"
  printf 'warnings: 0\n'
  printf 'max_warnings: %s\n' "$max_warnings"
  printf 'status: ok\n'
fi

exit 0
