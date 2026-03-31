# test.sh

## Purpose
Run smoke tests for timeout behavior and exit-code propagation.

## Location
`shared/timeout/test.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on `shared/safety/with-timeout.sh`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| none | N/A | N/A | No optional runtime flags |

## Usage
```bash
shared/timeout/test.sh
```

## Behavior
- Confirms success for command completing before timeout.
- Confirms timeout exit code `124` for long-running command.
- Confirms wrapped command non-zero status propagation.

## Output
- Standard output format: prints `PASS: timeout smoke tests` on success.
- Exit codes: `0` success, `1` assertion failure, `2` invalid args/dependency errors.
