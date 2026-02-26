# with-timeout.sh

## Purpose
Run a command with a hard timeout, signal escalation, and deterministic timeout exit behavior.

## Location
`shared/safety/with-timeout.sh`

## Preconditions
- Required tools: `bash`, `kill`, `sleep`, `mktemp`, `awk`, `date`
- Required permissions: permission to signal child process
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--timeout SEC` | Yes | N/A | Maximum runtime before timeout |
| `--signal SIGNAL` | No | `TERM` | Signal sent at timeout |
| `--grace SEC` | No | `5` | Wait before SIGKILL escalation |
| `--quiet` | No | `false` | Suppress timeout logs |
| `-- COMMAND [ARGS...]` | Yes | N/A | Command to run |

## Scenarios
- Happy path: command finishes within timeout and returns its exit code.
- Common operational path: hung command gets TERM and optionally KILL after grace.
- Failure path: invalid timeout/signal options or missing command.
- Recovery/rollback path: increase timeout/grace or optimize slow command path.

## Usage
```bash
shared/safety/with-timeout.sh --timeout 30 -- kubectl rollout status deploy/api
shared/safety/with-timeout.sh --timeout 5 --signal INT --grace 1 -- ./long-job.sh
shared/safety/with-timeout.sh --timeout 120 --quiet -- make test
```

## Behavior
- Main execution flow:
  - start child command
  - start watchdog timer
  - on timeout: signal child, wait grace, then SIGKILL if still running
  - return command status or timeout status
- Idempotency notes: wrapper is idempotent; wrapped command may not be.
- Side effects: process signaling and termination.

## Output
- Standard output format: wrapped command output; timeout log on stderr unless `--quiet`.
- Exit codes:
  - wrapped command exit code if completed in time
  - `124` timed out
  - `2` invalid script arguments

## Failure Modes
- Common errors and likely causes:
  - `--timeout is required`
  - invalid signal name
  - invalid timeout/grace value
- Recovery and rollback steps:
  - correct signal/time options
  - validate command runtime expectations
  - inspect command behavior under timeout pressure

## Security Notes
- Secret handling: command args may appear in outer process listings; avoid passing secrets in plaintext args.
- Least-privilege requirements: minimal privileges needed to signal child process.
- Audit/logging expectations: timeout events should be preserved in CI/job logs.

## Testing
- Unit tests:
  - option validation (`--timeout`, `--signal`, `--grace`)
- Integration tests:
  - sleep-based timeout and escalation behavior
- Manual verification:
  - run slow command and verify exit `124`
