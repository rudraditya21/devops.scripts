# verify.sh

## Purpose
Verify presence and integrity of `database` backup artifacts.

## Location
`backup/database/verify.sh`

## Preconditions
- Required tools: `bash`, checksum tool (`sha256sum` or `shasum`) for checksum verification
- Required permissions: read access to backup/checksum files
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--backup PATH` | Yes | N/A | Backup artifact to verify |
| `--checksum-file PATH` | No | `<backup>.sha256` | Checksum file path |
| `--json` | No | `false` | Emit JSON output |

## Usage
```bash
backup/database/verify.sh --backup /backups/database/app.tar.gz
backup/database/verify.sh --backup /backups/database/app.tar.gz --json
```

## Output
- Exit codes: `0` pass/warn, `1` failure, `2` invalid arguments.
