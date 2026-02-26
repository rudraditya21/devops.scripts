# dry-run.sh

## Purpose
Standardize dry-run behavior for shell automation by printing command intent without executing mutations.

## Location
`shared/safety/dry-run.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission for wrapped command when not in dry-run mode
- Required environment variables: optional `DRY_RUN`

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--dry-run` | No | from `DRY_RUN` env | Force dry-run mode |
| `--execute` | No | from `DRY_RUN` env | Force execution mode |
| `--prefix TEXT` | No | `DRY-RUN` | Prefix for dry-run message |
| `--quiet` | No | `false` | Suppress dry-run message |
| `-- COMMAND [ARGS...]` | Yes | N/A | Command to print/execute |

## Scenarios
- Happy path: in dry-run mode, command is printed and not executed.
- Common operational path: CI pipeline toggles execution via `DRY_RUN`.
- Failure path: missing command or bad flags returns usage error.
- Recovery/rollback path: rerun with `--execute` after validation.

## Usage
```bash
shared/safety/dry-run.sh --dry-run -- terraform apply
DRY_RUN=1 shared/safety/dry-run.sh -- kubectl delete ns temp
shared/safety/dry-run.sh --execute -- ./migrate.sh
```

## Behavior
- Main execution flow:
  - resolve dry-run mode from env/flags
  - validate command input
  - print quoted command in dry-run mode or execute directly
- Idempotency notes: dry-run branch is non-mutating; execution branch depends on wrapped command.
- Side effects: none in dry-run mode; wrapped command side effects in execute mode.

## Output
- Standard output format:
  - dry-run mode: `<prefix>: <quoted command>` to stderr (unless `--quiet`)
  - execute mode: wrapped command output
- Exit codes:
  - `0` dry-run success or wrapped command success
  - wrapped command non-zero exit in execute mode
  - `2` invalid script arguments

## Failure Modes
- Common errors and likely causes:
  - no command passed after `--`
  - conflicting assumptions on dry-run state
- Recovery and rollback steps:
  - pass explicit `--dry-run`/`--execute` for clarity
  - verify command arguments before execution mode

## Security Notes
- Secret handling: dry-run output may include full arguments; avoid secret-bearing args in logged channels.
- Least-privilege requirements: no elevated privileges for dry-run path.
- Audit/logging expectations: useful for change preview in approval workflows.

## Testing
- Unit tests:
  - env/flag precedence for dry-run mode
  - command quoting behavior
- Integration tests:
  - verify no mutation occurs in dry-run mode
- Manual verification:
  - compare behavior for `--dry-run` vs `--execute`
