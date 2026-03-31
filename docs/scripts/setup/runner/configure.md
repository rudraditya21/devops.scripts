# configure.sh

## Purpose
Configure baseline runner environment defaults for workspace, artifacts, and logging.

## Location
`setup/runner/configure.sh`

## Preconditions
- Required tools: `bash`, `mkdir`
- Required permissions: write access to config and workspace paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--env-file PATH` | No | `~/.config/devops-runner/env` | Env file path |
| `--workspace DIR` | No | `~/work` | Runner workspace path |
| `--artifacts-dir DIR` | No | `~/work/artifacts` | Artifacts path |
| `--log-level LEVEL` | No | `info` | Runner log level |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Happy path: prepare a runner host with consistent environment defaults.
- Common operational path: set custom workspace/artifact locations for CI nodes.
- Failure path: config path not writable.
- Recovery/rollback path: fix permissions and rerun with `--dry-run` first.

## Usage
```bash
setup/runner/configure.sh
setup/runner/configure.sh --workspace /var/lib/runner/work --artifacts-dir /var/lib/runner/artifacts
```

## Behavior
- Main execution flow: create required directories and write env configuration.
- Idempotency notes: repeat runs overwrite env file with latest values.
- Side effects: writes config file and creates directories.

## Output
- Standard output format: dry-run traces on stderr when enabled.
- Exit codes: `0` success, `2` invalid arguments.

## Failure Modes
- Common errors: permission denied while creating dirs/writing file.
- Recovery: run with accessible paths and correct ownership.

## Security Notes
- Secret handling: stores non-secret runtime configuration only.
- Least-privilege requirements: user-level directory write access.
- Audit/logging expectations: changes should be tracked in runner bootstrap logs.

## Testing
- Unit tests: argument parsing and path handling.
- Integration tests: verify env file creation on clean runner host.
- Manual verification: source env file and confirm variable values.
