#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: dry-run.sh [OPTIONS]

Simulate compliance security execution.

Options:
  --target NAME           Target scope (default: global)
  --profile NAME          Security profile (default: baseline)
  --output PATH           Optional output file
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

target="global"
profile="baseline"
output=""

while (($#)); do
  case "$1" in
    --target) shift; (($#)) || die "--target requires a value"; target="$1" ;;
    --profile) shift; (($#)) || die "--profile requires a value"; profile="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

msg="DRY-RUN: domain=compliance target=$target profile=$profile"
if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$msg" > "$output"
else
  printf '%s\n' "$msg"
fi

exit 0
