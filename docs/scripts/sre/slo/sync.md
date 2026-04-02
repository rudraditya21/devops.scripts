# sync.sh

## Purpose
Sync `slo` SRE metadata between source and destination paths.

## Location
`sre/slo/sync.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: read/write based on source and destination paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--source PATH` | Yes | N/A | Source path/identifier |
| `--destination PATH` | Yes | N/A | Destination path/identifier |
| `--json` | No | `false` | Emit JSON output |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
sre/slo/sync.sh --source ./in --destination ./out --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
