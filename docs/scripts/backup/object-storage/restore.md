# restore.sh

## Purpose
Restore `object-storage` backup artifacts into a target path.

## Location
`backup/object-storage/restore.sh`

## Preconditions
- Required tools: `bash`, `tar`, `cp`
- Required permissions: read access to input and write access to target
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--input PATH` | Yes | N/A | Backup artifact path |
| `--target PATH` | Yes | N/A | Restore target directory |
| `--strip-components N` | No | `0` | Path stripping for archive extraction |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
backup/object-storage/restore.sh --input /backups/object-storage/app.tar.gz --target /restore/app
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
