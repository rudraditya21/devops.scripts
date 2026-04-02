# healthcheck.sh

## Purpose
Run baseline health checks for `runbook` SRE workflows.

## Location
`sre/runbook/healthcheck.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: read access to optional local state file
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--strict` | No | `false` | Treat WARN/SKIP as failure |
| `--json` | No | `false` | Emit JSON output |

## Usage
```bash
sre/runbook/healthcheck.sh --strict
```

## Output
- Exit codes: `0` success, `1` failed healthcheck, `2` invalid arguments.
