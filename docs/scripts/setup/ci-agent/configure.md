# configure.sh

## Purpose
Configure CI agent queue, workspace, and artifact defaults.

## Location
`setup/ci-agent/configure.sh`

## Preconditions
- Required tools: `bash`, `mkdir`
- Required permissions: write access to config/workspace paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--config-file PATH` | No | `~/.config/devops-ci-agent/config.env` | Config output path |
| `--queue NAME` | No | `default` | Agent queue label |
| `--workspace DIR` | No | `~/work/ci-agent` | Workspace path |
| `--artifacts-dir DIR` | No | `~/work/ci-agent/artifacts` | Artifacts path |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Configure a fresh CI host.
- Align queue labels across multiple agents.

## Usage
```bash
setup/ci-agent/configure.sh --queue linux-build
```

## Behavior
- Creates directories and writes config env file.
- Idempotent overwrite behavior for config updates.

## Output
- Dry-run output on stderr.
- Exit codes: `0` success, `2` invalid arguments.

## Failure Modes
- Write permission denied.
- Invalid path values.

## Security Notes
- Stores non-secret settings only.

## Testing
- Validate generated config file values.
- Run with `--dry-run` for change preview.
