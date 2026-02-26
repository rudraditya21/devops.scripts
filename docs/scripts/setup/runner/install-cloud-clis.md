# install-cloud-clis.sh

## Purpose
Install cloud provider CLIs for AWS, GCP, and Azure operations on runners.

## Location
`setup/runner/install-cloud-clis.sh`

## Preconditions
- Required tools: `bash`, package manager, optional `sudo`
- Required permissions: package installation privileges
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tools CSV` | No | `aws,gcloud,az` | Tool set to install |
| `--tool NAME` | No | none | Add one tool (repeatable) |
| `--manager NAME` | No | `auto` | `auto\|brew\|apt\|dnf\|yum` |
| `--yes` | No | `false` | Non-interactive mode |
| `--update-cache` | No | `false` | Refresh package metadata |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: cloud CLIs installed and ready for auth/bootstrap.
- Common operational path: install subset of provider CLIs for environment-specific runners.
- Failure path: package repo lacks provider package or permissions are insufficient.
- Recovery/rollback path: adjust manager/repository or install subset and rerun.

## Usage
```bash
setup/runner/install-cloud-clis.sh --yes
setup/runner/install-cloud-clis.sh --tools aws,gcloud
setup/runner/install-cloud-clis.sh --tool az --dry-run
```

## Behavior
- Main execution flow: parse tool list, map package names, install missing commands.
- Idempotency notes: existing CLIs are skipped.
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
  - package unavailable in configured repositories
  - permission failures on install
- Recovery and rollback steps:
  - verify repositories and manager selection
  - rerun with corrected tool list or permissions

## Security Notes
- Secret handling: no credentials handled during install.
- Least-privilege requirements: elevate only during package operations.
- Audit/logging expectations: installation actions should be logged in runner provisioning.

## Testing
- Unit tests:
  - tool parsing/mapping validation
- Integration tests:
  - install flow on each supported package manager
- Manual verification:
  - `aws --version`, `gcloud --version`, `az version`
