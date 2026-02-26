# bootstrap-linux-runner.sh

## Purpose
Bootstrap a Linux runner with required tooling and baseline configuration for devops.scripts automation.

## Location
`setup/runner/bootstrap-linux-runner.sh`

## Preconditions
- Required tools: `bash`, package manager (`apt`/`dnf`/`yum`/`brew`), optional `sudo`
- Required permissions: package install and system service privileges for full setup
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--manager NAME` | No | `auto` | Package manager selector |
| `--yes` | No | `false` | Non-interactive install mode |
| `--dry-run` | No | `false` | Print actions without execution |
| `--update-cache` | No | `false` | Refresh package metadata |
| `--skip-docker` | No | `false` | Skip Docker setup |
| `--skip-k8s` | No | `false` | Skip Kubernetes tool setup |
| `--skip-cloud` | No | `false` | Skip cloud CLI setup |
| `--skip-healthcheck` | No | `false` | Skip final runner healthcheck |

## Scenarios
- Happy path: full bootstrap succeeds and runner healthcheck passes.
- Common operational path: run with selective `--skip-*` flags for targeted provisioning.
- Failure path: missing package manager/sudo or downstream installer failure.
- Recovery/rollback path: fix failing step and rerun bootstrap idempotently.

## Usage
```bash
setup/runner/bootstrap-linux-runner.sh --yes --update-cache
setup/runner/bootstrap-linux-runner.sh --manager apt --skip-cloud
setup/runner/bootstrap-linux-runner.sh --dry-run
```

## Behavior
- Main execution flow: calls setup/local and setup/runner installers + baseline configs + healthcheck.
- Idempotency notes: orchestrator is rerunnable; underlying installers skip existing tools when possible.
- Side effects: package installs, config updates, optional docker service enable/start.

## Output
- Standard output format: timestamped step logs.
- Exit codes:
  - `0` successful bootstrap
  - non-zero from failing step
  - `2` invalid arguments or unsupported OS

## Failure Modes
- Common errors and likely causes:
  - not running on Linux
  - package install failures/repository issues
  - missing privileges for service or package operations
- Recovery and rollback steps:
  - rerun failed sub-script directly for diagnosis
  - fix package repos/permissions
  - rerun bootstrap with required flags

## Security Notes
- Secret handling: no secrets required by default.
- Least-privilege requirements: use least privilege; elevate only for install/service actions.
- Audit/logging expectations: preserve bootstrap logs in runner build artifacts.

## Testing
- Unit tests:
  - flag parsing and skip logic
- Integration tests:
  - container/VM bootstrap validation on Linux distributions
- Manual verification:
  - run `setup/runner/runner-healthcheck.sh` after bootstrap
