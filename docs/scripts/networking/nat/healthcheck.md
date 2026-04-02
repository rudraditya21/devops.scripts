# healthcheck.sh

## Purpose
Run baseline health checks for `nat` networking workflows.

## Location
`networking/nat/healthcheck.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: none
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--endpoint HOST` | No | empty | Optional endpoint label |
| `--strict` | No | `false` | Treat WARN/SKIP as failure where applicable |
| `--json` | No | `false` | Emit JSON output |

## Usage
```bash
networking/nat/healthcheck.sh --endpoint edge.example.internal --strict
```

## Output
- Exit codes: `0` success, `1` healthcheck failure, `2` invalid arguments.
