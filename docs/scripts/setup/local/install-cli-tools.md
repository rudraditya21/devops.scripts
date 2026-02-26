# install-cli-tools.sh

## Purpose
Install common DevOps CLI tooling using the host package manager with repeatable, scriptable behavior.

## Location
`setup/local/install-cli-tools.sh`

## Preconditions
- Required tools: `bash`, selected package manager (`brew`, `apt-get`, `dnf`, or `yum`), optional `sudo`
- Required permissions: package-install privileges on workstation
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tools CSV` | No | built-in tool set | Comma-separated tool list |
| `--tool NAME` | No | none | Add one tool (repeatable) |
| `--manager NAME` | No | `auto` | `auto\|brew\|apt\|dnf\|yum` |
| `--yes` | No | `false` | Non-interactive package install |
| `--dry-run` | No | `false` | Print commands only |
| `--update-cache` | No | `false` | Refresh package metadata before install |

## Scenarios
- Happy path: missing tools are installed, existing tools are skipped.
- Common operational path: bootstrap a fresh developer workstation.
- Failure path: unsupported manager/tool mapping or package install failure.
- Recovery/rollback path: rerun with explicit manager/tool list and fixed package sources.

## Usage
```bash
setup/local/install-cli-tools.sh --update-cache --yes
setup/local/install-cli-tools.sh --manager brew --tools git,jq,shellcheck,shfmt
setup/local/install-cli-tools.sh --tool kubectl --tool terraform --dry-run
```

## Behavior
- Main execution flow: detect manager, optionally update cache, install requested/missing tools.
- Idempotency notes: idempotent for already-installed tools.
- Side effects: system package installation and updates.

## Output
- Standard output format: timestamped installation logs on stderr.
- Exit codes:
  - `0` all requested tools available/installed
  - `1` one or more tools failed/unsupported
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - no supported package manager found
  - package unavailable in configured repositories
  - insufficient privileges for system install
- Recovery and rollback steps:
  - verify repository configuration and credentials
  - rerun with explicit `--manager`
  - install failed tools manually and rerun verification

## Security Notes
- Secret handling: no secret input expected.
- Least-privilege requirements: use elevated privileges only for package operations.
- Audit/logging expectations: installation logs should be retained during bootstrap.

## Testing
- Unit tests:
  - manager/tool mapping logic
  - argument parsing
- Integration tests:
  - dry-run/install behavior on supported OS images
- Manual verification:
  - run then confirm each tool in `PATH`
