# install-k8s-tools.sh

## Purpose
Install core Kubernetes ecosystem CLIs required for cluster operations and CI automation.

## Location
`setup/runner/install-k8s-tools.sh`

## Preconditions
- Required tools: `bash`, package manager, optional `sudo`
- Required permissions: package installation privileges
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tools CSV` | No | `kubectl,helm,kustomize,kind` | Tool set to install |
| `--tool NAME` | No | none | Add one tool (repeatable) |
| `--manager NAME` | No | `auto` | `auto\|brew\|apt\|dnf\|yum` |
| `--yes` | No | `false` | Non-interactive mode |
| `--update-cache` | No | `false` | Refresh package metadata |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: requested Kubernetes tools installed successfully.
- Common operational path: install only subset needed by specific runner pools.
- Failure path: unsupported tool/manager mapping or install failure.
- Recovery/rollback path: adjust tool list/manager and rerun.

## Usage
```bash
setup/runner/install-k8s-tools.sh --yes
setup/runner/install-k8s-tools.sh --tools kubectl,helm
setup/runner/install-k8s-tools.sh --tool kind --tool kustomize --dry-run
```

## Behavior
- Main execution flow: normalize tool list, map package names per manager, install missing tools.
- Idempotency notes: skips tools already present.
- Side effects: package installation.

## Output
- Standard output format: timestamped install logs.
- Exit codes:
  - `0` all requested tools installed/present
  - `1` one or more tools failed/unsupported
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - unsupported tool name
  - package unavailable in repo
  - missing privileges for install
- Recovery and rollback steps:
  - fix tool names and manager mapping
  - ensure repository availability

## Security Notes
- Secret handling: none.
- Least-privilege requirements: elevate only for package operations.
- Audit/logging expectations: capture install outcomes in bootstrap logs.

## Testing
- Unit tests:
  - tool parsing and manager mapping
- Integration tests:
  - installation on supported package managers
- Manual verification:
  - `kubectl version --client`, `helm version`, `kind version`
