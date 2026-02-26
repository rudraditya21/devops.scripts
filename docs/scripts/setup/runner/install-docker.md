# install-docker.sh

## Purpose
Install Docker and optionally start/enable the daemon on Linux runners.

## Location
`setup/runner/install-docker.sh`

## Preconditions
- Required tools: `bash`, package manager, optional `sudo`, optional `systemctl`
- Required permissions: package install privileges; service management for daemon actions
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--manager NAME` | No | `auto` | `auto\|brew\|apt\|dnf\|yum` |
| `--yes` | No | `false` | Non-interactive install mode |
| `--update-cache` | No | `false` | Refresh package metadata |
| `--start-service` | No | `true` | Start/enable daemon on Linux |
| `--no-start-service` | No | `false` | Skip daemon startup |
| `--add-user-to-docker-group` | No | `false` | Add user to docker group (Linux) |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: Docker installed and daemon started (Linux).
- Common operational path: install binary only in immutable environments.
- Failure path: missing package manager or insufficient privileges.
- Recovery/rollback path: fix package/service permissions and rerun.

## Usage
```bash
setup/runner/install-docker.sh --yes --update-cache
setup/runner/install-docker.sh --manager apt --no-start-service
setup/runner/install-docker.sh --add-user-to-docker-group
```

## Behavior
- Main execution flow: detect manager, install package if needed, manage service/group options.
- Idempotency notes: skip install when docker already exists.
- Side effects: package install, daemon state changes, optional group membership changes.

## Output
- Standard output format: timestamped progress logs.
- Exit codes:
  - `0` success
  - `1` install/runtime failure
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - unsupported manager selection
  - package not found in repositories
  - no permission for service/group updates
- Recovery and rollback steps:
  - verify repositories and package availability
  - rerun with elevated privileges where required

## Security Notes
- Secret handling: none.
- Least-privilege requirements: avoid unnecessary root usage outside install/service steps.
- Audit/logging expectations: record daemon/group changes for compliance.

## Testing
- Unit tests:
  - manager detection and option validation
- Integration tests:
  - install/start behavior on Linux/macOS test images
- Manual verification:
  - `docker --version` and `docker info`
