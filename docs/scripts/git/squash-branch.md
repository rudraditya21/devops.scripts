# squash-branch.sh

## Purpose
Squash all branch commits since merge-base into a single curated commit safely.

## Location
`git/squash-branch.sh`

## Preconditions
- Required tools: `bash`, `git`, `date`
- Required permissions: branch rewrite rights; push permissions when `--push`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--base REF` | Yes | N/A | Base ref for squash boundary |
| `--branch NAME` | No | current branch | Branch to squash |
| `--message TEXT` | Cond. | N/A | Squash commit message |
| `--message-file PATH` | Cond. | N/A | Commit message file |
| `--push` | No | `false` | Push rewritten history |
| `--remote NAME` | No | `origin` | Remote target |
| `--yes` | No | `false` | Required when `--push` |
| `--no-fetch` | No | `false` | Skip pre-flight fetch |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Happy path: branch commits are squashed into one commit and kept local.
- Common operational path: squash feature branch before merge request finalization.
- Failure path: dirty worktree, invalid base, or no commits to squash.
- Recovery/rollback path: reset to generated backup branch.

## Usage
```bash
git/squash-branch.sh --base origin/main --message "feat(api): consolidate billing endpoints"
git/squash-branch.sh --base release/2.1 --message-file .git/SQUASH_MSG
git/squash-branch.sh --base origin/main --message "fix(auth): simplify token flow" --push --yes
```

## Behavior
- Main execution flow:
  - validates refs and message inputs
  - ensures clean working tree
  - computes merge-base and commit span
  - creates backup branch
  - soft-resets to merge-base and creates single commit
  - optionally force-pushes with lease
- Idempotency notes: non-idempotent due commit history rewrite.
- Side effects: rewrites branch history; creates backup branch; optional remote force update.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` argument/state validation failure
  - git command exit code for runtime failures

## Failure Modes
- Common errors and likely causes:
  - missing commit message input
  - branch equals base
  - rejected force push due lease mismatch/policy
- Recovery and rollback steps:
  - restore from backup branch
  - rebase/merge latest remote then retry push
  - rerun with corrected message/ref values

## Security Notes
- Secret handling: commit messages may contain sensitive data; validate before push.
- Least-privilege requirements: minimal repo permissions plus optional force-push rights.
- Audit/logging expectations: history rewrite events should be tracked in PR notes/review comments.

## Testing
- Unit tests:
  - mutual exclusivity (`--message` vs `--message-file`)
  - clean-tree and commit-count checks
- Integration tests:
  - squash on feature branch and validate single commit output
  - push path with `--force-with-lease`
- Manual verification:
  - inspect `git log --oneline <base>..HEAD` and ensure one commit remains
