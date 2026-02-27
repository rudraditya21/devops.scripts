# repo-healthcheck.sh

## Purpose
Assess repository health with structured checks for sync state, cleanliness, hooks, and metadata.

## Location
`git/repo-healthcheck.sh`

## Preconditions
- Required tools: `bash`, `git`, `wc`, `awk`
- Required permissions: read access to repository and tracked files
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--remote NAME` | No | `origin` | Remote to evaluate |
| `--default-branch NAME` | No | remote HEAD or `main` | Default branch override |
| `--max-file-mb N` | No | `10` | Warn threshold for tracked file size |
| `--require-clean` | No | `false` | Treat dirty tree as failure |
| `--strict` | No | `false` | Exit non-zero on warnings |
| `--json` | No | `false` | Emit JSON report |

## Scenarios
- Happy path: repository passes health checks with no warnings.
- Common operational path: run before release cut or branch protection tightening.
- Failure path: detached HEAD, dirty worktree, missing upstream, oversized tracked files.
- Recovery/rollback path: clean tree, configure upstream/hooks, reduce large artifacts.

## Usage
```bash
git/repo-healthcheck.sh
git/repo-healthcheck.sh --strict --require-clean
git/repo-healthcheck.sh --json --max-file-mb 5
```

## Behavior
- Main execution flow:
  - validates repository context
  - checks branch/remote/upstream/default-branch state
  - checks tracked/untracked cleanliness
  - scans tracked files for size threshold violations
  - verifies key metadata files and pre-push hook presence
- Idempotency notes: read-only diagnostic script.
- Side effects: none.

## Output
- Standard output format: table or JSON (`--json`) with summary counts.
- Exit codes:
  - `0` no failure checks (or no warns in strict mode)
  - `1` failed checks present or strict-mode warnings
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - missing remote/default branch references
  - dirty repository state
  - oversized tracked artifacts
- Recovery and rollback steps:
  - configure remote/upstream and fetch
  - commit/stash working changes
  - move large assets to artifact storage/LFS and clean history if needed

## Security Notes
- Secret handling: script reads tracked files only for size; does not inspect content semantics.
- Least-privilege requirements: read-only repo access is sufficient.
- Audit/logging expectations: JSON output is suitable for CI evidence retention.

## Testing
- Unit tests:
  - threshold and status aggregation logic
  - argument validation
- Integration tests:
  - run on clean vs intentionally dirty branches
  - strict-mode exit behavior
- Manual verification:
  - validate summary against `git status`, `git branch -vv`, and file size spot checks
