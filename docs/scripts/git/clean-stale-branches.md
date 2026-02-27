# clean-stale-branches.sh

## Purpose
Identify and clean stale local/remote branches using age and merge-state safeguards.

## Location
`git/clean-stale-branches.sh`

## Preconditions
- Required tools: `bash`, `git`, `date`
- Required permissions: local branch deletion rights; remote branch delete rights for remote cleanup
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--base REF` | No | remote HEAD | Base ref for merged checks |
| `--remote NAME` | No | `origin` | Remote source/target |
| `--min-age-days N` | No | `30` | Minimum branch age to classify stale |
| `--include-unmerged` | No | `false` | Include unmerged branches |
| `--delete-remote` | No | `false` | Delete stale branches on remote |
| `--protect CSV` | No | empty | Extra protected branch names |
| `--apply` | No | `false` | Execute deletions (default preview) |
| `--yes` | No | `false` | Required with remote deletion in apply mode |
| `--force-local` | No | `false` | Use `-D` for local deletes when unmerged included |
| `--no-fetch` | No | `false` | Skip `fetch --prune` |

## Scenarios
- Happy path: preview stale branches and then apply cleanup safely.
- Common operational path: monthly branch hygiene for long-lived repos.
- Failure path: invalid base ref, protected branch targeting, remote delete permissions.
- Recovery/rollback path: recreate branches from remote/reflog if accidental deletion occurs.

## Usage
```bash
git/clean-stale-branches.sh --min-age-days 45
git/clean-stale-branches.sh --apply --min-age-days 60
git/clean-stale-branches.sh --include-unmerged --force-local --apply --delete-remote --yes
```

## Behavior
- Main execution flow:
  - resolves base reference and protected branch set
  - scans local and remote refs by age threshold
  - filters by merge status unless unmerged inclusion enabled
  - prints candidate list in preview mode
  - deletes candidates only when `--apply` (and explicit remote confirmation)
- Idempotency notes: preview mode is idempotent; apply mode converges as branches are removed.
- Side effects: local branch deletion; optional remote branch deletion.

## Output
- Standard output format: summary with stale candidate lists and timestamped action logs.
- Exit codes:
  - `0` success
  - `1` one or more deletions failed in apply mode
  - `2` invalid options/safety gate violations

## Failure Modes
- Common errors and likely causes:
  - base ref not found
  - remote delete requested without `--apply --yes`
  - unmerged branch delete blocked without `--force-local`
- Recovery and rollback steps:
  - rerun in preview mode to validate target set
  - restore branches from reflog/remote refs
  - tune protection list and rerun

## Security Notes
- Secret handling: no secret material processed.
- Least-privilege requirements: local branch ops by default; remote delete rights only when explicitly enabled.
- Audit/logging expectations: remote deletions should align with branch lifecycle policies and team approvals.

## Testing
- Unit tests:
  - stale candidate filtering (age/protected/merged)
  - safety gate checks for destructive options
- Integration tests:
  - preview/apply workflows on sample branch matrix
  - remote deletion behavior with controlled remote
- Manual verification:
  - compare candidate set with `git for-each-ref` and merge-base checks before apply
