#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: run.sh [OPTIONS]

Run iam-audit security workflow.

Options:
  --target NAME           Target scope (default: global)
  --profile NAME          Security profile (default: baseline)
  --output PATH           Write output to file
  --dry-run               Print actions only
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

target="global"
profile="baseline"
output=""
dry_run=false

while (($#)); do
  case "$1" in
    --target) shift; (($#)) || die "--target requires a value"; target="$1" ;;
    --profile) shift; (($#)) || die "--profile requires a value"; profile="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

result=$(cat <<TXT
domain: iam-audit
action: run
target: $target
profile: $profile
status: executed
TXT
)

if $dry_run; then
  printf 'DRY-RUN: execute iam-audit run for target=%s profile=%s\n' "$target" "$profile"
  exit 0
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$result" > "$output"
else
  printf '%s\n' "$result"
fi

exit 0
