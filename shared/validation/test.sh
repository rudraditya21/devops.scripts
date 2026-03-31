#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: test.sh [OPTIONS]

Run smoke tests for shared/core validation scripts.

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

require_cmd_script="$repo_root/shared/core/require-cmd.sh"
require_env_script="$repo_root/shared/core/require-env.sh"

[[ -x "$require_cmd_script" ]] || die "missing dependency: $require_cmd_script"
[[ -x "$require_env_script" ]] || die "missing dependency: $require_env_script"

bash "$require_cmd_script" bash > /dev/null

set +e
bash "$require_cmd_script" __definitely_missing_command__ > /dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 1 ]] || fail "require-cmd should return 1 when a command is missing"

TEST_REQUIRED_VAR="ok" bash "$require_env_script" TEST_REQUIRED_VAR > /dev/null

set +e
env -i PATH="$PATH" bash "$require_env_script" TEST_REQUIRED_VAR > /dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 1 ]] || fail "require-env should return 1 for missing vars"

set +e
TEST_REQUIRED_VAR="" bash "$require_env_script" TEST_REQUIRED_VAR > /dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 1 ]] || fail "require-env should return 1 for empty vars"

TEST_REQUIRED_VAR="" bash "$require_env_script" --allow-empty TEST_REQUIRED_VAR TEST_REQUIRED_VAR > /dev/null

printf 'PASS: validation smoke tests\n'
