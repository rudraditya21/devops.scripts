# report.sh

## Purpose
Generate `incident` SRE reports for period and owner views.

## Location
`sre/incident/report.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: write access when `--output` is used
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--period LABEL` | No | `24h` | Report period label |
| `--owner NAME` | No | `sre` | Owner/team label |
| `--format table\|json` | No | `table` | Output format |
| `--output PATH` | No | stdout | Output file |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
sre/incident/report.sh --period 7d --owner platform --format json
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
