#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
while [[ ! -d "$ROOT_DIR/tests/lib" && "$ROOT_DIR" != "/" ]]; do
  ROOT_DIR="$(dirname "$ROOT_DIR")"
done

if [[ ! -d "$ROOT_DIR/tests/lib" ]]; then
  printf 'Unable to locate repository root for %s\n' "setup/db-tools/verify.sh"
  exit 1
fi

SCRIPT_TEST_ROOT="$ROOT_DIR"
# shellcheck source=tests/lib/script_test_lib.sh
source "$ROOT_DIR/tests/lib/script_test_lib.sh"

run_script_suite "setup/db-tools/verify.sh" "setup/db-tools/verify.sh"
