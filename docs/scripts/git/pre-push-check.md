# pre-push-check.sh

## Purpose
Run a configurable pre-push quality gate covering branch sync, commit message quality, and project checks.

## Location
`git/pre-push-check.sh`

## Preconditions
- Required tools: `bash`, `git`, `make`, `awk`, `mktemp`
- Required permissions: repo read/write as needed by invoked checks
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--remote NAME` | No | `origin` | Remote to inspect |
| `--base REF` | No | remote HEAD or `origin/main` | Fallback comparison base |
| `--allow-behind` | No | `false` | Do not fail when behind upstream |
| `--skip-format-check` | No | `false` | Skip `make format-check` |
| `--skip-lint` | No | `false` | Skip `make lint` |
| `--skip-docs-build` | No | `false` | Skip `make docs-build` |
| `--skip-commit-msg` | No | `false` | Skip outgoing commit message validation |
| `--custom-check CMD` | No | empty | Additional command (repeatable) |
| `--strict` | No | `false` | Fail on WARN checks |
| `--no-fetch` | No | `false` | Skip fetch before checks |
| `--dry-run` | No | `false` | Preview check plan only |

## Scenarios
- Happy path: branch is synchronized, commit messages valid, all quality targets pass.
- Common operational path: run in local pre-push hook and CI dry-run validation.
- Failure path: branch behind upstream, lint/docs build failure, or invalid outgoing commit messages.
- Recovery/rollback path: sync branch, fix quality issues, rerun gate.

## Usage
```bash
git/pre-push-check.sh
git/pre-push-check.sh --allow-behind --custom-check "pytest -q"
git/pre-push-check.sh --skip-docs-build --dry-run
```

## Behavior
- Main execution flow:
  - validates remote/base refs and upstream status
  - validates outgoing commit messages with `git/validate-commit-msg.sh`
  - executes available make targets (`format-check`, `lint`, `docs-build`) unless skipped
  - executes custom checks and emits summary table
- Idempotency notes: check-only script; no mutation in normal mode.
- Side effects: optional fetch, build/lint command execution.

## Output
- Standard output format: tabular summary of `PASS|WARN|FAIL` checks.
- Exit codes:
  - `0` all required checks passed
  - `1` one or more checks failed (or warn in strict mode)
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - upstream behind status
  - missing make targets
  - failing lint/docs/tests in custom checks
- Recovery and rollback steps:
  - rebase/merge latest upstream
  - run failing check directly and remediate
  - tune skips only for approved exception paths

## Security Notes
- Secret handling: avoid embedding secrets in custom check commands.
- Least-privilege requirements: run with developer-level local permissions.
- Audit/logging expectations: check results should be attached to PR evidence for release-critical changes.

## Testing
- Unit tests:
  - make-target discovery and option parsing
  - commit-range calculation logic
- Integration tests:
  - hook-style execution on sample branches
  - strict/warn behavior
- Manual verification:
  - compare output against known failing/passing states
