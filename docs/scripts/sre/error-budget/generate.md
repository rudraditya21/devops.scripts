# generate.sh

## Purpose
Generate `error-budget` SRE artifacts for a service/window context.

## Location
`sre/error-budget/generate.sh`

## Preconditions
- Required tools: `bash`, `date`
- Required permissions: write access when `--output` is used
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--service NAME` | Yes | N/A | Service name |
| `--window LABEL` | No | `current` | Time window label |
| `--output PATH` | No | stdout | Output file |
| `--json` | No | `false` | Emit JSON output |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
sre/error-budget/generate.sh --service payments --window 24h --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
