# bootstrap-macos-runner.sh

## Purpose
Bootstrap a macOS runner with required tooling and baseline configuration for devops.scripts automation.

## Location
`setup/runner/bootstrap-macos-runner.sh`

## Preconditions
- Required tools: `bash`, Homebrew (`brew`) or `--install-brew` path
- Required permissions: package install permissions
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--yes` | No | `false` | Non-interactive install mode |
| `--dry-run` | No | `false` | Print actions without execution |
| `--update-cache` | No | `false` | Refresh package metadata |
| `--skip-docker` | No | `false` | Skip Docker installation |
| `--skip-k8s` | No | `false` | Skip Kubernetes tool setup |
| `--skip-cloud` | No | `false` | Skip cloud CLI setup |
| `--skip-healthcheck` | No | `false` | Skip final runner healthcheck |
| `--install-brew` | No | `false` | Install Homebrew if missing |

## Scenarios
- Happy path: Homebrew present, tools configured, healthcheck passes.
- Common operational path: bootstrap managed macOS runners for CI jobs.
- Failure path: Homebrew missing and `--install-brew` not provided, or install failures.
- Recovery/rollback path: install Homebrew/dependencies and rerun.

## Usage
```bash
setup/runner/bootstrap-macos-runner.sh --yes --update-cache
setup/runner/bootstrap-macos-runner.sh --skip-cloud
setup/runner/bootstrap-macos-runner.sh --dry-run --install-brew
```

## Behavior
- Main execution flow: install base/local/runner tools and apply local configurations.
- Idempotency notes: rerunnable orchestration with skip/installed checks.
- Side effects: package installs, configuration file updates.

## Output
- Standard output format: timestamped step logs.
- Exit codes:
  - `0` successful bootstrap
  - non-zero from failing step
  - `2` invalid arguments or unsupported OS

## Failure Modes
- Common errors and likely causes:
  - script run on non-macOS host
  - Homebrew install/access issues
  - sub-installer failure
- Recovery and rollback steps:
  - validate brew setup and network access
  - rerun failing sub-script directly
  - rerun bootstrap with corrected flags

## Security Notes
- Secret handling: no default secret requirements.
- Least-privilege requirements: local user-level operations preferred.
- Audit/logging expectations: retain bootstrap logs for runner provenance.

## Testing
- Unit tests:
  - flag and step selection behavior
- Integration tests:
  - macOS CI runner bootstrap smoke test
- Manual verification:
  - run `setup/runner/runner-healthcheck.sh` post-bootstrap
