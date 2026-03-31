#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: test.sh [OPTIONS]

Run smoke tests for shared/safety/retry.sh.

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
retry_script="$repo_root/shared/safety/retry.sh"

[[ -x "$retry_script" ]] || die "missing dependency: $retry_script"

tmp_dir="$(mktemp -d "$tmp_base/shared-retry-test.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

counter_file="$tmp_dir/counter.txt"
flaky_script="$tmp_dir/flaky.sh"

cat > "$flaky_script" <<'FLAKY'
#!/usr/bin/env bash
set -euo pipefail
counter_file="$1"
count=0
if [[ -f "$counter_file" ]]; then
  count="$(cat "$counter_file")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$counter_file"
if ((count < 3)); then
  exit 42
fi
exit 0
FLAKY
chmod +x "$flaky_script"

bash "$retry_script" --attempts 3 --delay 0 --backoff 1 --retry-on 42 -- "$flaky_script" "$counter_file"
[[ "$(cat "$counter_file")" == "3" ]] || fail "expected 3 attempts for flaky command"

set +e
bash "$retry_script" --attempts 5 --delay 0 --retry-on 42 -- bash -lc 'exit 7' > /dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 7 ]] || fail "expected non-retryable status 7, got $status"

set +e
bash "$retry_script" --attempts 2 --delay 0 --backoff 1 --retry-on 42 -- bash -lc 'exit 42' > /dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 42 ]] || fail "expected retry exhaustion status 42, got $status"

printf 'PASS: retry smoke tests\n'
