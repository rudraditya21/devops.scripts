# dr-test.sh

## Purpose
Run disaster-recovery smoke tests for the `object-storage` backup workflow.

## Location
`backup/object-storage/dr-test.sh`

## Preconditions
- Required tools: `bash`, `mktemp`
- Required permissions: read access to source, write access to temp/work directories
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--source PATH` | Yes | N/A | Source path used for DR simulation |
| `--workdir DIR` | No | temp dir | Work directory for generated artifacts |
| `--keep-workdir` | No | `false` | Keep workdir after completion |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
backup/object-storage/dr-test.sh --source /data/app
```

## Output
- Exit codes: `0` success, non-zero on failure.
