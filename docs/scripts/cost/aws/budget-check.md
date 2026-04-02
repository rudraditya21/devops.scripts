# budget-check.sh

## Purpose
Check `aws` spend against budget and warning thresholds.

## Location
`cost/aws/budget-check.sh`

## Preconditions
- Required tools: `bash`, `awk`
- Required permissions: none
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--budget-limit AMOUNT` | Yes | N/A | Budget ceiling |
| `--current-spend AMOUNT` | Yes | N/A | Current spend |
| `--warn-percent N` | No | `80` | Warn threshold |
| `--json` | No | `false` | Emit JSON output |
| `--fail-on-breach` | No | `false` | Exit non-zero on breach |

## Usage
```bash
cost/aws/budget-check.sh --budget-limit 2000 --current-spend 1710 --warn-percent 85
```

## Output
- Exit codes: `0` success/non-breach, `1` breach with `--fail-on-breach`, `2` invalid arguments.
