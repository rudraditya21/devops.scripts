# retention-cleanup.sh

## Purpose
Prune expired `object-storage` backup artifacts by retention policy.

## Location
`backup/object-storage/retention-cleanup.sh`

## Preconditions
- Required tools: `bash`, `find`
- Required permissions: delete permission on backup directory
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--backup-dir DIR` | No | `./backups/object-storage` | Backup directory to prune |
| `--days N` | No | `30` | Retention window in days |
| `--pattern GLOB` | No | `*` | File selection pattern |
| `--dry-run` | No | `false` | Print matching files only |

## Usage
```bash
backup/object-storage/retention-cleanup.sh --backup-dir /backups/object-storage --days 14 --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
