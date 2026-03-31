# example.sh

## Purpose
Provide a convenience wrapper demonstrating command timeout execution.

## Location
`shared/timeout/example.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on `shared/safety/with-timeout.sh`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--timeout SEC` | No | `5` | Command timeout in seconds |
| `--signal SIGNAL` | No | `TERM` | Signal sent on timeout |
| `--grace SEC` | No | `1` | Grace before SIGKILL |
| `--quiet` | No | `false` | Suppress timeout logs |
| `-- COMMAND ...` | No | built-in sample command | Command to run under timeout |

## Usage
```bash
shared/timeout/example.sh
shared/timeout/example.sh --timeout 30 --grace 2 -- terraform apply -auto-approve
```

## Output
- Exit codes: same behavior as `shared/safety/with-timeout.sh`.
