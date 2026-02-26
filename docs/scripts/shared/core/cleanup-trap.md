# cleanup-trap.sh

## Purpose
Execute a command and guarantee reverse-order cleanup command execution on completion or termination signals.

## Location
`shared/core/cleanup-trap.sh`

## Preconditions
- Required tools: `bash`, `sed`, `date`, `kill`
- Required permissions: permission to run target and cleanup commands
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cleanup "CMD"` | Yes (at least one total cleanup source) | none | Inline cleanup command (repeatable) |
| `--cleanup-file FILE` | No | none | File containing cleanup commands (one per line) |
| `--verbose` | No | `false` | Log signal and cleanup execution details |
| `-- COMMAND [ARGS...]` | Yes | N/A | Target command to execute |

## Scenarios
- Happy path: command succeeds and cleanup commands execute in reverse order.
- Common operational path: trap service startup and ensure resource teardown on interrupts.
- Failure path: invalid options or missing cleanup/command exits `2`.
- Recovery/rollback path: fix cleanup declarations; rerun with verbose mode to diagnose failures.

## Usage
```bash
shared/core/cleanup-trap.sh --cleanup 'rm -f /tmp/app.lock' -- /bin/sh -c 'echo running'

shared/core/cleanup-trap.sh \
  --cleanup 'echo second cleanup' \
  --cleanup 'echo first cleanup' \
  --verbose \
  -- /bin/sh -c 'sleep 5'

shared/core/cleanup-trap.sh --cleanup-file ./cleanup.cmds -- /bin/sh -c 'exit 0'
```

## Behavior
- Main execution flow:
  - parse cleanup definitions and target command
  - install signal handlers for `INT`, `TERM`, `HUP`
  - run target command as child process
  - run cleanup commands once, in reverse registration order
- Idempotency notes: cleanup execution is guarded to run once.
- Side effects: executes arbitrary cleanup shell commands.

## Output
- Standard output format:
  - target command output unchanged
  - optional verbose log lines with timestamp, level, and message
- Exit codes:
  - target command exit code by default
  - `70` when cleanup fails while target command succeeded
  - `2` usage/configuration error
  - signal-aligned code (`130`, `143`, `129`) on trapped termination when cleanup succeeds

## Failure Modes
- Common errors and likely causes:
  - missing `--cleanup` and no cleanup-file entries
  - unreadable cleanup-file
  - cleanup command returns non-zero
- Recovery and rollback steps:
  - validate cleanup file permissions/format
  - run with `--verbose` and fix failing cleanup commands
  - ensure cleanup commands are safe to rerun

## Security Notes
- Secret handling: avoid embedding secrets in cleanup command literals.
- Least-privilege requirements: execute with minimum privileges needed for target and cleanup operations.
- Audit/logging expectations: prefer `--verbose` during incident/debug workflows.

## Testing
- Unit tests:
  - parse validation and cleanup-file ingestion
  - reverse-order execution logic
- Integration tests:
  - signal handling (`INT`, `TERM`) and single-run cleanup guarantee
- Manual verification:
  - run with temporary marker files to confirm cleanup ordering and exit semantics
