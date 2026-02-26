# Engineering Standards

These are mandatory standards for all scripts in this repository.

## Script Design

- Use POSIX-compliant shell where practical; use Bash explicitly when advanced features are needed.
- Start with `set -euo pipefail`.
- Fail fast on invalid input.
- Keep scripts single-purpose and composable.
- Prefer deterministic output and explicit flags over implicit behavior.

## Safety Requirements

- Support `--dry-run` for mutating operations.
- Require explicit confirmation for destructive operations.
- Never hardcode secrets or credentials.
- Log every critical operation with context.

## Observability Requirements

- Structured logs with timestamp and severity.
- Clear error paths and actionable failure messages.
- Exit with non-zero status on failure.

## Testing Requirements

- Add tests for argument parsing, validation, and core behavior.
- Include at least one failure-path test.
- Include at least one idempotency/safety test where applicable.

## Documentation Requirements

Each script must document:

- Purpose and scope
- Required tools and versions
- Required environment variables
- Arguments and defaults
- Examples
- Failure modes and troubleshooting
- Rollback and recovery notes

## Review Gate

A script can be merged only when:

- Lint and tests pass
- Documentation is complete
- Safety controls are present
- A reviewer validates production readiness
