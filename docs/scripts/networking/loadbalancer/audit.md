# audit.sh

## Purpose
Audit `loadbalancer` networking objects and report status findings.

## Location
`networking/loadbalancer/audit.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: read-only access to networking metadata source
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--scope NAME` | No | `global` | Scope label |
| `--json` | No | `false` | Emit JSON output |

## Usage
```bash
networking/loadbalancer/audit.sh --scope production
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
