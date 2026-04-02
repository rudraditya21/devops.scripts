# Script Test Suite

This suite provides generated Bash smoke/validation tests for every script in the repository.

## Structure
- Mirrors repository script layout under `tests/...`.
- One `*_test.sh` wrapper per script.
- Shared helpers in `tests/lib/script_test_lib.sh`.

## Coverage Model
For each script, tests include:
- `--help` returns success.
- Unknown option is rejected.
- Every discovered flag is tested.
  - Value flags: missing value, invalid value, valid value.
  - Boolean flags: accepted in invocation.
- Required flags are included in base invocations with generated sample values.
- Uses `--dry-run` automatically when available.

## Run
```bash
bash tests/run_all_tests.sh
```
