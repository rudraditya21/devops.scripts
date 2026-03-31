# test.sh

## Purpose
Run smoke tests for shared core validation scripts.

## Location
`shared/validation/test.sh`

## Preconditions
- Required tools: `bash`, `env`
- Required permissions: execute permission on dependency scripts
- Required environment variables: `PATH`

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| none | N/A | N/A | No optional runtime flags |

## Usage
```bash
shared/validation/test.sh
```

## Behavior
- Verifies `require-cmd` success and missing-command failure.
- Verifies `require-env` for set, missing, empty, and `--allow-empty` cases.

## Output
- Standard output format: prints `PASS: validation smoke tests` on success.
- Exit codes: `0` success, `1` assertion failure, `2` invalid args/dependency errors.
