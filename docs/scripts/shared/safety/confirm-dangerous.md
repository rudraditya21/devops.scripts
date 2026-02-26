# confirm-dangerous.sh

## Purpose
Enforce explicit human confirmation before running potentially destructive operations.

## Location
`shared/safety/confirm-dangerous.sh`

## Preconditions
- Required tools: `bash`, interactive stdin for prompted mode
- Required permissions: none beyond script execution
- Required environment variables: optional `CONFIRM_DANGEROUS`

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--message TEXT` | No | destructive warning message | Context shown to operator |
| `--prompt TEXT` | No | `Type '<token>' to continue` | Prompt text |
| `--expect TOKEN` | No | `CONFIRM` | Required input token |
| `-y`, `--yes` | No | `false` | Non-interactive bypass |
| `--timeout SEC` | No | `0` | Prompt timeout in seconds |

## Scenarios
- Happy path: operator types expected token and script exits `0`.
- Common operational path: audited automation uses `--yes` or `CONFIRM_DANGEROUS=1`.
- Failure path: mismatch, timeout, or non-interactive stdin without override exits `1`.
- Recovery/rollback path: rerun with explicit approval and validated context.

## Usage
```bash
shared/safety/confirm-dangerous.sh --message "About to delete production resources"
shared/safety/confirm-dangerous.sh --expect DELETE --prompt "Type DELETE to continue"
CONFIRM_DANGEROUS=1 shared/safety/confirm-dangerous.sh
```

## Behavior
- Main execution flow:
  - check non-interactive overrides
  - require interactive input when override absent
  - compare response with expected token
- Idempotency notes: idempotent; no mutable side effects.
- Side effects: user interaction and stderr messaging.

## Output
- Standard output format: confirmation status messages on stderr.
- Exit codes:
  - `0` confirmed
  - `1` confirmation rejected/timed out/unavailable
  - `2` invalid script arguments

## Failure Modes
- Common errors and likely causes:
  - running in non-interactive session without `--yes`
  - wrong confirmation token entered
  - read timeout reached
- Recovery and rollback steps:
  - rerun in interactive shell or with explicit audited override
  - confirm correct token before retry

## Security Notes
- Secret handling: avoid embedding secrets in prompt text.
- Least-privilege requirements: no elevated permissions required.
- Audit/logging expectations: pair with audit logging to record approval context.

## Testing
- Unit tests:
  - option validation and token matching
- Integration tests:
  - non-interactive behavior with and without overrides
- Manual verification:
  - interactive acceptance/rejection and timeout paths
