#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: test.sh [OPTIONS]

Run smoke tests for shared/safety/file-lock.sh.

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
file_lock_script="$repo_root/shared/safety/file-lock.sh"

[[ -x "$file_lock_script" ]] || die "missing dependency: $file_lock_script"

tmp_dir="$(mktemp -d "$tmp_base/shared-lock-test.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

lock_path="$tmp_dir/test.lock"

bash "$file_lock_script" --lock-file "$lock_path" --timeout 2 -- bash -lc 'exit 0'

bash "$file_lock_script" --lock-file "$lock_path" --timeout 5 -- bash -lc 'sleep 2' &
holder_pid=$!
sleep 0.2

set +e
bash "$file_lock_script" --lock-file "$lock_path" --timeout 1 --poll-interval 0.1 -- bash -lc 'exit 0' > /dev/null 2>&1
status=$?
set -e
wait "$holder_pid"
[[ "$status" -eq 73 ]] || fail "expected lock wait timeout status 73, got $status"

mkdir -p "$lock_path"
touch -t 200001010000 "$lock_path" 2> /dev/null || true
bash "$file_lock_script" --lock-file "$lock_path" --stale-after 1 --timeout 1 -- bash -lc 'exit 0'

printf 'PASS: lock smoke tests\n'
