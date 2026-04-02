# healthcheck.sh

## Purpose
Run basic health checks for `hook` git workflows.

## Location
`git/hook/healthcheck.sh`

## Preconditions
- Required tools: `bash`, `git`
- Required permissions: none
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--strict` | No | `false` | Treat WARN as failure |
| `--json` | No | `false` | Emit JSON output |

## Usage
```bash
git/hook/healthcheck.sh --strict
```

## Output
- Exit codes: `0` success, `1` failed healthcheck, `2` invalid arguments.
