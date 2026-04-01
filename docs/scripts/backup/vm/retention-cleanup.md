# retention-cleanup.sh

## Purpose
Prune expired `vm` backup artifacts by retention policy.

## Location
`backup/vm/retention-cleanup.sh`

## Preconditions
- Required tools: `bash`, `find`
- Required permissions: delete permission on backup directory
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--backup-dir DIR` | No | `./backups/vm` | Backup directory to prune |
| `--days N` | No | `30` | Retention window in days |
| `--pattern GLOB` | No | `*` | File selection pattern |
| `--dry-run` | No | `false` | Print matching files only |

## Usage
```bash
backup/vm/retention-cleanup.sh --backup-dir /backups/vm --days 14 --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
