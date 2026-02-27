# rebase-safe.sh

## Purpose
Run a guarded rebase with backup-branch creation and clear rollback instructions.

## Location
`git/rebase-safe.sh`

## Preconditions
- Required tools: `bash`, `git`, `date`
- Required permissions: ability to create refs and rewrite branch history
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--onto REF` | Yes | N/A | Rebase target reference |
| `--branch NAME` | No | current branch | Branch to rebase |
| `--remote NAME` | No | `origin` | Remote for fetch/ref fallback |
| `--no-fetch` | No | `false` | Skip remote fetch |
| `--autostash` | No | `false` | Auto-stash local changes during rebase |
| `--rebase-merges` | No | `false` | Preserve merge commits |
| `--autosquash` | No | `false` | Autosquash fixup/squash commits |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Happy path: branch rebased cleanly onto latest base and backup retained.
- Common operational path: refresh long-lived feature branch against `origin/main`.
- Failure path: rebase conflict or dirty tree without `--autostash`.
- Recovery/rollback path: `git rebase --abort` or hard reset to generated backup branch.

## Usage
```bash
git/rebase-safe.sh --onto origin/main
git/rebase-safe.sh --onto release/2.1 --branch feature/billing --autosquash
git/rebase-safe.sh --onto origin/main --autostash --dry-run
```

## Behavior
- Main execution flow:
  - validates refs and branch context
  - optionally fetches remote
  - creates timestamped backup branch
  - executes rebase with selected safety flags
  - prints rollback guidance if rebase fails
- Idempotency notes: non-idempotent (history rewrite each run).
- Side effects: commit SHAs on target branch change; backup branch created.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` argument/state validation failure
  - `git rebase` exit code on conflicts/failures

## Failure Modes
- Common errors and likely causes:
  - dirty worktree without `--autostash`
  - unresolved conflicts
  - invalid `--onto` ref
- Recovery and rollback steps:
  - run `git rebase --abort`
  - reset branch to backup (`git reset --hard <backup-branch>`)
  - resolve conflicts and re-run

## Security Notes
- Secret handling: no secret persistence or transport.
- Least-privilege requirements: local git write access only.
- Audit/logging expectations: history rewrites should be coordinated and reviewed before push.

## Testing
- Unit tests:
  - option parsing and ref resolution
  - clean-tree enforcement
- Integration tests:
  - successful rebase path
  - conflict path + rollback instructions
- Manual verification:
  - compare old/new commit graph and confirm backup branch exists
