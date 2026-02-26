# log-error.sh

## Purpose
Emit structured ERROR-level log lines and optionally terminate with a caller-defined exit code.

## Location
`shared/core/log-error.sh`

## Preconditions
- Required tools: `bash`, `date`
- Required permissions: execute permission on script file
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tag TAG` | No | `LOG_TAG` or script basename | Log tag value in output |
| `--timestamp-format FORMAT` | No | `LOG_TIMESTAMP_FORMAT` or `%Y-%m-%dT%H:%M:%S%z` | `date` format string |
| `--stream stdout\|stderr` | No | `stderr` | Output stream target |
| `--exit-code CODE` | No | unset | Exit after logging with numeric code `0..255` |
| `MESSAGE...` | Yes | N/A | Error message payload |

## Scenarios
- Happy path: print error message to stderr and exit `0` when `--exit-code` is not provided.
- Common operational path: enforce explicit failure (`--exit-code 1`) in calling scripts.
- Failure path: invalid numeric code or missing message returns exit `1`.
- Recovery/rollback path: fix bad flags; rerun with corrected `--exit-code` semantics.

## Usage
```bash
shared/core/log-error.sh "database connection failed"
shared/core/log-error.sh --tag api --exit-code 42 "fatal startup error"
shared/core/log-error.sh --stream stdout --tag batch "validation failed"
```

## Behavior
- Main execution flow: parse options, validate exit code if provided, require message, print line, optionally exit.
- Idempotency notes: idempotent with respect to system state.
- Side effects: writes one line; may terminate caller flow via exit status.

## Output
- Standard output format: `<timestamp> [ERROR] [<tag>] <message>`
- Exit codes:
  - `0` success when no `--exit-code` is passed
  - `N` when `--exit-code N` is passed
  - `1` invalid arguments or timestamp formatting failure

## Failure Modes
- Common errors and likely causes:
  - `exit code must be numeric`
  - `exit code must be <= 255`
  - `MESSAGE is required`
- Recovery and rollback steps:
  - use valid numeric exit code in range
  - provide message payload
  - correct invalid stream/timestamp values

## Security Notes
- Secret handling: avoid writing secret-bearing exceptions to logs.
- Least-privilege requirements: no elevated privileges required.
- Audit/logging expectations: pair with structured callers for incident timelines.

## Testing
- Unit tests:
  - code range validation (`0..255`)
  - optional exit behavior
- Integration tests:
  - verify caller script sees expected exit code
- Manual verification:
  - run with and without `--exit-code`, inspect output and status
