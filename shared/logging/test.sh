#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: test.sh [OPTIONS]

Run smoke tests for shared/core logging scripts.

Options:
  --tmp-dir DIR    Temp directory base for test artifacts
  -h, --help       Show help
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

tmp_base="${TMPDIR:-/tmp}"

while (($#)); do
  case "$1" in
    --tmp-dir)
      shift
      (($#)) || die "--tmp-dir requires a value"
      tmp_base="$1"
      ;;
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

log_info="$repo_root/shared/core/log-info.sh"
log_warn="$repo_root/shared/core/log-warn.sh"
log_error="$repo_root/shared/core/log-error.sh"

for dep in "$log_info" "$log_warn" "$log_error"; do
  [[ -x "$dep" ]] || die "missing dependency: $dep"
done

tmp_dir="$(mktemp -d "$tmp_base/shared-logging-test.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

out_file="$tmp_dir/out.log"

bash "$log_info" --tag test --stream stdout "hello info" > "$out_file"
grep -q '\[INFO\] \[test\] hello info' "$out_file" || fail "log-info output mismatch"

bash "$log_warn" --tag test --stream stdout "hello warn" > "$out_file"
grep -q '\[WARN\] \[test\] hello warn' "$out_file" || fail "log-warn output mismatch"

set +e
bash "$log_error" --tag test --stream stdout --exit-code 17 "hello error" > "$out_file" 2>&1
status=$?
set -e
[[ "$status" -eq 17 ]] || fail "log-error exit code mismatch (got $status, expected 17)"
grep -q '\[ERROR\] \[test\] hello error' "$out_file" || fail "log-error output mismatch"

printf 'PASS: logging smoke tests\n'
