# test.sh

## Purpose
Run smoke tests validating retry success and failure behaviors.

## Location
`shared/retry/test.sh`

## Preconditions
- Required tools: `bash`, `mktemp`
- Required permissions: execute permission on `shared/safety/retry.sh`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tmp-dir DIR` | No | `$TMPDIR` or `/tmp` | Base dir for temporary test artifacts |

## Usage
```bash
shared/retry/test.sh
```

## Behavior
- Tests flaky command recovery within configured attempts.
- Tests non-retryable exit code pass-through.
- Tests exhaustion when command keeps failing.

## Output
- Standard output format: prints `PASS: retry smoke tests` on success.
- Exit codes: `0` success, `1` assertion failure, `2` invalid args/dependency errors.
