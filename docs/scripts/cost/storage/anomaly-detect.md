# anomaly-detect.sh

## Purpose
Detect abnormal `storage` spend deviations relative to baseline.

## Location
`cost/storage/anomaly-detect.sh`

## Preconditions
- Required tools: `bash`, `awk`
- Required permissions: none
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--baseline AMOUNT` | Yes | N/A | Expected spend baseline |
| `--current AMOUNT` | Yes | N/A | Observed current spend |
| `--threshold-percent N` | No | `30` | Deviation threshold |
| `--json` | No | `false` | Emit JSON output |
| `--fail-on-anomaly` | No | `false` | Exit non-zero on anomaly |

## Usage
```bash
cost/storage/anomaly-detect.sh --baseline 900 --current 1310 --threshold-percent 25
```

## Output
- Exit codes: `0` normal/no-fail mode, `1` anomaly with `--fail-on-anomaly`, `2` invalid arguments.
