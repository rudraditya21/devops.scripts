# cleanup.sh

## Purpose
Clean local DevOps workstation caches and old log files safely.

## Location
`setup/local/cleanup.sh`

## Preconditions
- Required tools: `bash`, `find`, `rm`, `date`
- Required permissions: user write permission for selected cleanup paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cache-dir DIR` | No | `~/.cache/devops.scripts` | Cache dir to remove (repeatable) |
| `--logs-dir DIR` | No | `~/.local/state/devops.scripts/logs` | Log dir to prune (repeatable) |
| `--days N` | No | `14` | Delete logs older than N days |
| `--remove-tool-cache` | No | `false` | Also remove common tool caches |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Happy path: remove stale local caches and old logs after active development.
- Common operational path: run weekly as local hygiene task.
- Failure path: invalid path input or missing permissions.
- Recovery/rollback path: restore from backups if critical files were included unintentionally.

## Usage
```bash
setup/local/cleanup.sh --dry-run
setup/local/cleanup.sh --remove-tool-cache --days 7
setup/local/cleanup.sh --cache-dir "$HOME/.cache/devops.scripts" --logs-dir "$HOME/.local/state/devops.scripts/logs"
```

## Behavior
- Main execution flow:
  - resolves cleanup targets
  - removes cache directories
  - prunes old files in log directories
- Idempotency notes: repeatable; missing paths are ignored.
- Side effects: deletes files/directories.

## Output
- Standard output format: timestamped cleanup logs to stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments or unsafe path guard failure

## Failure Modes
- Common errors and likely causes:
  - path permission denied
  - invalid `--days` value
- Recovery and rollback steps:
  - rerun with `--dry-run`
  - fix permissions and retry

## Security Notes
- Secret handling: no secret values are printed.
- Least-privilege requirements: user-level filesystem permissions only.
- Audit/logging expectations: dry-run output can be attached to local maintenance logs.

## Testing
- Unit tests:
  - argument parsing and unsafe-path guard
- Integration tests:
  - prune temp directories in sandbox
- Manual verification:
  - compare `--dry-run` output with actual deletion results
