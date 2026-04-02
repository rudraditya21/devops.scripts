# sync.sh

## Purpose
Sync `release` git metadata between source and destination.

## Location
`git/release/sync.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: read/write depending on source and destination
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
git/release/sync.sh --source ./src --destination ./dst --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
