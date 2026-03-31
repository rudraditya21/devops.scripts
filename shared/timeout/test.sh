#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: test.sh [OPTIONS]

Run smoke tests for shared/safety/with-timeout.sh.

Options:
  -h, --help    Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
with_timeout_script="$repo_root/shared/safety/with-timeout.sh"

[[ -x "$with_timeout_script" ]] || die "missing dependency: $with_timeout_script"

bash "$with_timeout_script" --timeout 2 --grace 0 -- bash -lc 'sleep 0.1; exit 0' > /dev/null

set +e
bash "$with_timeout_script" --timeout 0.2 --grace 0 -- bash -lc 'sleep 2' > /dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 124 ]] || fail "expected timeout exit code 124, got $status"

set +e
bash "$with_timeout_script" --timeout 2 --grace 0 -- bash -lc 'exit 9' > /dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 9 ]] || fail "expected wrapped exit code 9, got $status"

printf 'PASS: timeout smoke tests\n'
