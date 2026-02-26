# verify-workstation.sh

## Purpose
Run workstation readiness checks for required tooling and baseline local DevOps configuration.

## Location
`setup/local/verify-workstation.sh`

## Preconditions
- Required tools: `bash`, `stat`, optional `git` for git-specific checks
- Required permissions: read access to user config files/directories
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--json` | No | `false` | Emit machine-readable JSON report |
| `--strict` | No | `false` | Treat WARN as failure |
| `--required-cmds CSV` | No | built-in list | Override required command set |
| `--required-cmd NAME` | No | none | Append one required command |

## Scenarios
- Happy path: all checks pass and script exits `0`.
- Common operational path: preflight verification before onboarding completion.
- Failure path: missing required command(s) or strict mode warnings.
- Recovery/rollback path: install/configure reported gaps and rerun checks.

## Usage
```bash
setup/local/verify-workstation.sh
setup/local/verify-workstation.sh --json
setup/local/verify-workstation.sh --strict --required-cmds git,curl,jq,terraform,kubectl
```

## Behavior
- Main execution flow: run command checks, git identity checks, and local config file/permission checks.
- Idempotency notes: read-only and idempotent.
- Side effects: none.

## Output
- Standard output format:
  - text table with PASS/WARN/FAIL summary
  - JSON summary/check list with `--json`
- Exit codes:
  - `0` no FAIL checks (and no WARN in strict mode)
  - `1` FAIL checks present, or WARN present in strict mode
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - required binaries not installed
  - missing git identity settings
  - missing ssh/gpg/kube/terraform config artifacts
- Recovery and rollback steps:
  - run setup scripts (`install-cli-tools`, `configure-*`, `setup-*`)
  - fix file permissions where warned
  - rerun verification until green

## Security Notes
- Secret handling: verification reads metadata only, not secret values.
- Least-privilege requirements: user-level read access.
- Audit/logging expectations: JSON mode suitable for CI gate ingestion.

## Testing
- Unit tests:
  - command list parsing and strict mode logic
- Integration tests:
  - simulate missing commands/config in isolated test HOME
- Manual verification:
  - run with and without `--strict` and confirm expected exit behavior
