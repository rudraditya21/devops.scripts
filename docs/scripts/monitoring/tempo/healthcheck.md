# healthcheck.sh

## Purpose
Run TCP healthcheck for `tempo` monitoring workflows.

## Location
`monitoring/tempo/healthcheck.sh`

## Preconditions
- Required tools: `bash`, optionally `nc` or `timeout`
- Required permissions: network access to target endpoint
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--target HOST` | No | `127.0.0.1` | Target host |
| `--port N` | No | stack default | Target port |
| `--timeout N` | No | `3` | Timeout seconds |
| `--json` | No | `false` | Emit JSON output |
| `--strict` | No | `false` | Exit non-zero when unhealthy |

## Usage
```bash
monitoring/tempo/healthcheck.sh --target 127.0.0.1 --strict
```

## Output
- Exit codes: `0` success, `1` failed strict healthcheck, `2` invalid arguments.
