# example.sh

## Purpose
Provide a convenience wrapper demonstrating lock-based serialized execution.

## Location
`shared/lock/example.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on `shared/safety/file-lock.sh`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--lock-file PATH` | No | `/tmp/devops-scripts-example.lock` | Lock path |
| `--timeout SEC` | No | `5` | Max wait time |
| `--poll-interval SEC` | No | `0.2` | Lock polling interval |
| `--stale-after SEC` | No | `0` | Stale lock age threshold |
| `--quiet` | No | `false` | Suppress lock logs |
| `-- COMMAND ...` | No | built-in sample command | Command to run with lock |

## Usage
```bash
shared/lock/example.sh
shared/lock/example.sh --lock-file /tmp/deploy.lock --timeout 60 -- ./scripts/deploy.sh
```

## Output
- Exit codes: same behavior as `shared/safety/file-lock.sh`.
