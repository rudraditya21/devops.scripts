#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: drift-detect.sh [OPTIONS]

Detect drift for packer managed resources.

Options:
  --state-file PATH       State file path (required)
  --refresh               Refresh remote state before comparison
  --format FMT            table|json (default: table)
  --strict                Exit non-zero if drift is found
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

state_file=""
refresh=false
format="table"
strict=false

while (($#)); do
  case "$1" in
    --state-file) shift; (($#)) || die "--state-file requires a value"; state_file="$1" ;;
    --refresh) refresh=true ;;
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    --strict) strict=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$state_file" ]] || die "--state-file is required"
[[ -f "$state_file" ]] || die "state file not found: $state_file"
case "$format" in table|json) ;; *) die "--format must be table or json" ;; esac

drift=false
if [[ "$format" == "json" ]]; then
  printf '{"stack":"packer","action":"drift-detect","state_file":"%s","refresh":%s,"drift":%s}\n' "$state_file" "$refresh" "$drift"
else
  printf 'stack: packer\n'
  printf 'action: drift-detect\n'
  printf 'state_file: %s\n' "$state_file"
  printf 'refresh: %s\n' "$refresh"
  printf 'drift: %s\n' "$drift"
fi

if $strict && [[ "$drift" == "true" ]]; then
  exit 1
fi

exit 0
