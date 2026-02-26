# file-lock.sh

## Purpose
Provide exclusive lock-based command execution to prevent concurrent unsafe operations.

## Location
`shared/safety/file-lock.sh`

## Preconditions
- Required tools: `bash`, `mkdir`, `rm`, `date`, `awk`, `sleep`, `stat`
- Required permissions: write permissions on lock path parent directory
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--lock-file PATH` | Yes | N/A | Lock directory path |
| `--timeout SEC` | No | `0` | Wait timeout (`0` waits indefinitely) |
| `--poll-interval SEC` | No | `0.2` | Poll interval while waiting |
| `--stale-after SEC` | No | `0` | Break stale lock older than SEC |
| `--quiet` | No | `false` | Suppress wait/stale logs |
| `-- COMMAND [ARGS...]` | Yes | N/A | Command to run while lock is held |

## Scenarios
- Happy path: lock acquired immediately; command runs and lock is released.
- Common operational path: multiple workers serialize writes safely.
- Failure path: lock wait timeout expires or lock path cannot be created.
- Recovery/rollback path: investigate stale lock owner, tune `--stale-after`, retry safely.

## Usage
```bash
shared/safety/file-lock.sh --lock-file /tmp/deploy.lock -- ./deploy.sh
shared/safety/file-lock.sh --lock-file /tmp/state.lock --timeout 60 -- terraform apply
shared/safety/file-lock.sh --lock-file /tmp/sync.lock --stale-after 300 -- ./sync-state.sh
```

## Behavior
- Main execution flow:
  - attempt atomic lock acquisition via `mkdir`
  - optionally break stale lock
  - run command under lock
  - release lock on exit/signals
- Idempotency notes: lock handling is idempotent for same process lifecycle.
- Side effects: lock directory create/remove and metadata file writes.

## Output
- Standard output format: wrapped command output; lock status logs on stderr unless `--quiet`.
- Exit codes:
  - wrapped command exit code
  - `73` timeout waiting for lock
  - `2` invalid script arguments

## Failure Modes
- Common errors and likely causes:
  - missing or invalid `--lock-file`
  - lock path parent not writable
  - stale lock removal failure
- Recovery and rollback steps:
  - correct filesystem permissions
  - inspect stale lock metadata (`.owner`)
  - manually clear lock only after owner validation

## Security Notes
- Secret handling: do not store secret values in lock path names.
- Least-privilege requirements: only filesystem permissions required for lock location.
- Audit/logging expectations: lock wait/timeout logs useful for concurrency incident analysis.

## Testing
- Unit tests:
  - timeout and stale lock validation logic
- Integration tests:
  - concurrent process contention and serialization behavior
- Manual verification:
  - run two commands against same lock path and confirm mutual exclusion
