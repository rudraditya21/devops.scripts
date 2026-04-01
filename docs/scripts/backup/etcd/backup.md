# backup.sh

## Purpose
Create backup artifacts for the `etcd` backup domain.

## Location
`backup/etcd/backup.sh`

## Preconditions
- Required tools: `bash`, `tar`, `cp`
- Required permissions: read access to source and write access to output path
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--source PATH` | Yes | N/A | Source file/directory to back up |
| `--output PATH` | Yes | N/A | Backup artifact path |
| `--compress` | No | `true` | Create compressed tar archive |
| `--no-compress` | No | `false` | Copy source without compression |
| `--metadata KV` | No | none | Metadata key/value entries |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
backup/etcd/backup.sh --source /data/app --output /backups/etcd/app-2026-04-01.tar.gz
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
