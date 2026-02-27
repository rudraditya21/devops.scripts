# branch-delete.sh

## Purpose
Delete local branches safely with protection controls and optional remote deletion.

## Location
`git/branch-delete.sh`

## Preconditions
- Required tools: `bash`, `git`, `date`
- Required permissions: local ref deletion rights; remote push rights for `--delete-remote`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Branch to delete |
| `--force` | No | `false` | Force local deletion (`-D`) |
| `--delete-remote` | No | `false` | Delete remote branch as well |
| `--remote NAME` | No | `origin` | Remote to target |
| `--protect CSV` | No | empty | Extra protected branch names |
| `--yes` | No | `false` | Required for remote deletion |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Happy path: merged local branch deleted with safe `-d`.
- Common operational path: delete local + remote feature branch after merge.
- Failure path: target branch is protected or currently checked out.
- Recovery/rollback path: recreate deleted branch from remote or reflog.

## Usage
```bash
git/branch-delete.sh --name feature/api-hardening
git/branch-delete.sh --name feature/api-hardening --delete-remote --yes
git/branch-delete.sh --name spike/parser --force --dry-run
```

## Behavior
- Main execution flow:
  - validates git context and branch name
  - blocks deletion of protected/current branch
  - deletes local branch with safe/force mode
  - optionally deletes remote branch (guarded by `--yes`)
- Idempotency notes: repeated runs become no-op/fail once branch no longer exists.
- Side effects: removes branch refs locally and optionally on remote.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments or blocked unsafe action
  - git command exit code for delete failures

## Failure Modes
- Common errors and likely causes:
  - protected branch refusal
  - branch is checked out
  - remote delete denied by branch policies
- Recovery and rollback steps:
  - switch branches before delete
  - remove accidental protection override
  - restore from `git reflog` or remote branch recreation

## Security Notes
- Secret handling: no secret processing.
- Least-privilege requirements: only branch-level write rights required.
- Audit/logging expectations: remote deletes are traceable via provider audit trails.

## Testing
- Unit tests:
  - protection list matching
  - required `--yes` enforcement for remote deletion
- Integration tests:
  - local delete merged/unmerged branches
  - remote delete path with mocked remote
- Manual verification:
  - `git branch -a` before/after and remote branch checks
