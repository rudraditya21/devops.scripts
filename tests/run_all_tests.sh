#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN='\033[32m'
RED='\033[31m'
RESET='\033[0m'

passed=0
failed=0

while IFS= read -r test_file; do
  printf 'Running %s\n' "${test_file#$ROOT_DIR/}"
  if bash "$test_file"; then
    printf '%b[PASSED]%b %s\n' "$GREEN" "$RESET" "${test_file#$ROOT_DIR/}"
    passed=$((passed + 1))
  else
    printf '%b[FAILED]%b %s\n' "$RED" "$RESET" "${test_file#$ROOT_DIR/}"
    failed=$((failed + 1))
  fi
  printf '\n'
done < <(find "$ROOT_DIR/tests" -type f -name '*_test.sh' ! -path '*/lib/*' | sort)

printf 'Total: %s passed, %s failed\n' "$passed" "$failed"
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
