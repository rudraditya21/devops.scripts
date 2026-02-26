# runner-healthcheck.sh

## Purpose
Validate runner readiness across core commands, platform support, and optional tool domains.

## Location
`setup/runner/runner-healthcheck.sh`

## Preconditions
- Required tools: `bash`, `uname`, `awk`, optional domain CLIs being checked
- Required permissions: read/execute access for command checks
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--json` | No | `false` | Emit JSON report |
| `--strict` | No | `false` | Treat WARN as failure |
| `--no-docker-check` | No | `false` | Skip Docker checks |
| `--no-k8s-check` | No | `false` | Skip Kubernetes checks |
| `--no-cloud-check` | No | `false` | Skip cloud CLI checks |
| `--no-terraform-check` | No | `false` | Skip Terraform check |
| `--no-gpg-check` | No | `false` | Skip GPG check |
| `--required-cmds CSV` | No | built-in core list | Override required command set |
| `--required-cmd NAME` | No | none | Add one required command |

## Scenarios
- Happy path: all required checks pass with zero FAIL results.
- Common operational path: run in CI bootstrap to gate runner promotion.
- Failure path: missing critical binaries or unsupported OS.
- Recovery/rollback path: install/fix missing components and rerun until green.

## Usage
```bash
setup/runner/runner-healthcheck.sh
setup/runner/runner-healthcheck.sh --json --strict
setup/runner/runner-healthcheck.sh --no-cloud-check --required-cmds bash,git,curl,jq
```

## Behavior
- Main execution flow: run grouped checks, compute summary counts, emit text/JSON report.
- Idempotency notes: read-only and idempotent.
- Side effects: none.

## Output
- Standard output format:
  - text table by default
  - JSON object with summary/check list via `--json`
- Exit codes:
  - `0` no FAIL (and no WARN under strict mode)
  - `1` FAIL present, or WARN present in strict mode
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - missing required tools in PATH
  - docker daemon unreachable despite binary presence
  - unsupported host OS
- Recovery and rollback steps:
  - run corresponding installer scripts
  - fix service/runtime configuration
  - rerun healthcheck with strict mode before promotion

## Security Notes
- Secret handling: does not access secrets.
- Least-privilege requirements: no elevated privileges required.
- Audit/logging expectations: JSON output is suitable for compliance pipelines.

## Testing
- Unit tests:
  - option parsing and summary exit behavior
- Integration tests:
  - controlled environments with missing tools to validate PASS/WARN/FAIL logic
- Manual verification:
  - run after bootstrap and confirm expected report shape
