# example.sh

## Purpose
Demonstrate INFO/WARN/ERROR logging flows using shared core logging scripts.

## Location
`shared/logging/example.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on dependency scripts
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tag TAG` | No | `logging-example` | Tag used in log output |
| `--stream stdout\|stderr` | No | `stderr` | Target output stream |
| `--info-message MSG` | No | built-in default | INFO message payload |
| `--warn-message MSG` | No | built-in default | WARN message payload |
| `--error-message MSG` | No | built-in default | ERROR message payload |
| `--skip-error` | No | `false` | Skip error line |

## Scenarios
- Happy path: emit INFO/WARN/ERROR lines with one command.
- Failure path: missing core logging dependency scripts.

## Usage
```bash
shared/logging/example.sh
shared/logging/example.sh --tag deploy --stream stdout --skip-error
```

## Behavior
- Resolves repository root and validates logging dependencies.
- Calls `shared/core/log-info.sh`, `shared/core/log-warn.sh`, and optionally `shared/core/log-error.sh`.

## Output
- Standard output format: same format produced by core log scripts.
- Exit codes: `0` success, `2` invalid args/dependency errors.
