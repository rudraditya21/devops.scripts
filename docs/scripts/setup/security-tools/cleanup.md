# cleanup.sh

## Purpose
Clean stale temporary security artifacts (keys/certs/signature files) from a target directory.

## Location
`setup/security-tools/cleanup.sh`

## Preconditions
- Required tools: `bash`, `find`
- Required permissions: delete access to target directory
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--temp-dir DIR` | No | `/tmp` | Temp directory to clean |
| `--days N` | No | `7` | Remove files older than N days |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
setup/security-tools/cleanup.sh --dry-run
setup/security-tools/cleanup.sh --temp-dir /var/tmp --days 3
```

## Behavior
- Removes matching key/cert/signature file patterns older than threshold.

## Output
- Dry-run listing or silent deletion.

## Failure Modes
- Permission denied while deleting files.

## Security Notes
- Helps reduce long-lived sensitive temp artifacts.

## Testing
- Verify with sample files in isolated temp directories.
