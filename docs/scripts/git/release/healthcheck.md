# healthcheck.sh

## Purpose
Run basic health checks for `release` git workflows.

## Location
`git/release/healthcheck.sh`

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
git/release/healthcheck.sh --strict
```

## Output
- Exit codes: `0` success, `1` failed healthcheck, `2` invalid arguments.
