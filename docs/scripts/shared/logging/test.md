# test.sh

## Purpose
Run smoke tests for shared core logging scripts.

## Location
`shared/logging/test.sh`

## Preconditions
- Required tools: `bash`, `mktemp`, `grep`
- Required permissions: execute permission on dependency scripts
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tmp-dir DIR` | No | `$TMPDIR` or `/tmp` | Base dir for temporary artifacts |

## Scenarios
- Happy path: verifies INFO/WARN output patterns and `log-error` exit code handling.
- Failure path: output mismatch or missing dependency scripts.

## Usage
```bash
shared/logging/test.sh
shared/logging/test.sh --tmp-dir /tmp
```

## Behavior
- Executes `log-info`, `log-warn`, `log-error` with deterministic inputs.
- Asserts expected output snippets and status code.

## Output
- Standard output format: prints `PASS: logging smoke tests` on success.
- Exit codes: `0` success, `1` assertion failure, `2` argument/dependency errors.
