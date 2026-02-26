# require-cmd.sh

## Purpose
Validate that required CLI binaries are present in `PATH` before executing dependent automation.

## Location
`shared/core/require-cmd.sh`

## Preconditions
- Required tools: `bash`, `command -v`
- Required permissions: execute permission on script file
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--quiet` | No | `false` | Suppress success message in non-JSON mode |
| `--json` | No | `false` | Emit machine-readable JSON report |
| `COMMAND [COMMAND...]` | Yes | N/A | Command names to validate |

## Scenarios
- Happy path: all commands exist; script exits `0`.
- Common operational path: run preflight checks in CI/CD and output JSON for parsers.
- Failure path: one or more commands missing; script exits `1`.
- Recovery/rollback path: install missing binaries or adjust PATH, then rerun.

## Usage
```bash
shared/core/require-cmd.sh bash sed awk
shared/core/require-cmd.sh --json kubectl helm terraform
shared/core/require-cmd.sh --quiet jq
```

## Behavior
- Main execution flow: parse flags, verify each command using `command -v`, collect present/missing sets.
- Idempotency notes: idempotent and read-only.
- Side effects: none besides stdout/stderr output.

## Output
- Standard output format:
  - text mode: success line or missing-command error
  - JSON mode: `{"required":[],"missing":[],"resolved":[{"command":"...","path":"..."}]}`
- Exit codes:
  - `0` all commands available
  - `1` one or more commands missing
  - `2` usage/argument error

## Failure Modes
- Common errors and likely causes:
  - `at least one COMMAND is required`
  - `unknown option`
  - missing commands in runtime image/host
- Recovery and rollback steps:
  - install missing tools
  - ensure PATH includes tool directories
  - fix invocation options

## Security Notes
- Secret handling: no secret processing.
- Least-privilege requirements: read-only command lookup.
- Audit/logging expectations: useful in preflight logs for reproducibility.

## Testing
- Unit tests:
  - option parsing (`--quiet`, `--json`)
  - empty command validation
- Integration tests:
  - validate behavior when a known fake command is requested
- Manual verification:
  - run with both existing and non-existing command names
