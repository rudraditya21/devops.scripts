# test.sh

## Purpose
Run smoke tests for lock acquisition, contention timeout, and stale lock recovery.

## Location
`shared/lock/test.sh`

## Preconditions
- Required tools: `bash`, `mktemp`, `mkdir`, `touch`
- Required permissions: execute permission on `shared/safety/file-lock.sh`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tmp-dir DIR` | No | `$TMPDIR` or `/tmp` | Base dir for temporary test artifacts |

## Usage
```bash
shared/lock/test.sh
```

## Behavior
- Verifies normal lock acquisition path.
- Verifies timeout behavior under lock contention (`73`).
- Verifies stale lock cleanup path with `--stale-after`.

## Output
- Standard output format: prints `PASS: lock smoke tests` on success.
- Exit codes: `0` success, `1` assertion failure, `2` invalid args/dependency errors.
