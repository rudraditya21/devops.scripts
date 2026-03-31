# cleanup.sh

## Purpose
Prune old database backup artifacts from a target backup directory.

## Location
`setup/db-tools/cleanup.sh`

## Preconditions
- Required tools: `bash`, `find`
- Required permissions: write/delete access to backup directory
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--backup-dir DIR` | No | `~/backups` | Directory containing backup files |
| `--days N` | No | `30` | Delete files older than N days |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
setup/db-tools/cleanup.sh --dry-run
setup/db-tools/cleanup.sh --backup-dir /srv/backups --days 14
```

## Behavior
- Removes old `sql`, `dump`, `backup`, and `gz` backup files.

## Output
- Dry-run file listing or silent deletion.

## Failure Modes
- Permission denied on backup directory.

## Security Notes
- Operates on file metadata only.

## Testing
- Validate with synthetic backup files and known mtimes.
