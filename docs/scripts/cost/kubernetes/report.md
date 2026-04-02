# report.sh

## Purpose
Generate `kubernetes` cost report snapshots for a selected time window.

## Location
`cost/kubernetes/report.sh`

## Preconditions
- Required tools: `bash`, `date`
- Required permissions: write access when `--output` is used
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--start-date YYYY-MM-DD` | No | first day of current month | Report start date |
| `--end-date YYYY-MM-DD` | No | current date | Report end date |
| `--estimated-total AMOUNT` | No | `0` | Estimated spend |
| `--currency CODE` | No | `USD` | Currency code |
| `--scope NAME` | No | `global` | Scope label |
| `--format table\|json` | No | `table` | Output format |
| `--output PATH` | No | stdout | Write output to file |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
cost/kubernetes/report.sh --estimated-total 1243.77 --scope production
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
