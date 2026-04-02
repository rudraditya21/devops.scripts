# rightsizing.sh

## Purpose
Generate `gcp` rightsizing guidance from utilization metrics.

## Location
`cost/gcp/rightsizing.sh`

## Preconditions
- Required tools: `bash`, `awk`
- Required permissions: none
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cpu-util PERCENT` | Yes | N/A | Current CPU utilization |
| `--memory-util PERCENT` | Yes | N/A | Current memory utilization |
| `--cpu-target PERCENT` | No | `55` | Target CPU utilization |
| `--memory-target PERCENT` | No | `65` | Target memory utilization |
| `--json` | No | `false` | Emit JSON output |

## Usage
```bash
cost/gcp/rightsizing.sh --cpu-util 21 --memory-util 30
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
