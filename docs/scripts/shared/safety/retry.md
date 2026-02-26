# retry.sh

## Purpose
Retry a command on failure with configurable attempts, delay, backoff, and retry-code filtering.

## Location
`shared/safety/retry.sh`

## Preconditions
- Required tools: `bash`, `awk`, `sleep`, `date`
- Required permissions: execute permission for target command and this script
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--attempts N` | No | `3` | Total number of attempts |
| `--delay SEC` | No | `1` | Initial delay before retry |
| `--backoff FACTOR` | No | `2` | Multiplier applied to delay |
| `--max-delay SEC` | No | `0` | Delay cap (`0` disables cap) |
| `--jitter PERCENT` | No | `0` | Positive jitter percentage added to delay |
| `--retry-on CODES` | No | all non-zero | Comma-separated exit codes to retry |
| `--quiet` | No | `false` | Suppress retry logs |
| `-- COMMAND [ARGS...]` | Yes | N/A | Command to execute and retry |

## Scenarios
- Happy path: command succeeds on first attempt and exits `0`.
- Common operational path: transient failures recover after one or more retries.
- Failure path: command keeps failing or returns non-retryable status.
- Recovery/rollback path: tune retry policy (`--retry-on`, attempts/delay) and rerun.

## Usage
```bash
shared/safety/retry.sh --attempts 5 --delay 1 --backoff 2 -- curl -fsS https://example.com/health
shared/safety/retry.sh --retry-on 1,2,28 --attempts 4 --delay 0.5 -- terraform plan
shared/safety/retry.sh --quiet --attempts 3 -- make deploy
```

## Behavior
- Main execution flow:
  - validate retry policy options
  - execute command
  - retry on eligible non-zero statuses until attempt limit
  - exit with command status
- Idempotency notes: wrapper is idempotent; wrapped command may not be.
- Side effects: repeated execution of wrapped command.

## Output
- Standard output format: wrapped command output; retry logs on stderr unless `--quiet`.
- Exit codes:
  - `0` command eventually succeeded
  - wrapped command exit code on final/non-retryable failure
  - `2` invalid script arguments

## Failure Modes
- Common errors and likely causes:
  - invalid numeric options (`--attempts`, `--delay`, etc.)
  - missing command after `--`
  - bad retry code list format
- Recovery and rollback steps:
  - correct option values
  - ensure command is present and executable
  - reduce retry scope for non-idempotent commands

## Security Notes
- Secret handling: avoid printing secrets in wrapped command args or stderr.
- Least-privilege requirements: run with minimum privileges required by wrapped command.
- Audit/logging expectations: retry logs support incident and change tracing.

## Testing
- Unit tests:
  - argument validation
  - retry-on filtering logic
- Integration tests:
  - flaky command simulation with deterministic exit codes
- Manual verification:
  - force failure then success and confirm retry timing/status behavior
