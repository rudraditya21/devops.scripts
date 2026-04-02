# recommendations-export.sh

## Purpose
Export `azure` cost optimization recommendations in CSV or JSON.

## Location
`cost/azure/recommendations-export.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: write access when `--output` is used
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--format csv\|json` | No | `csv` | Output format |
| `--top N` | No | `5` | Number of recommendations |
| `--output PATH` | No | stdout | Write output to file |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
cost/azure/recommendations-export.sh --format json --top 10
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
