# branch-create.sh

## Purpose
Create a new branch from a validated base reference with optional checkout and upstream push.

## Location
`git/branch-create.sh`

## Preconditions
- Required tools: `bash`, `git`, `date`
- Required permissions: write access to `.git` refs and branch metadata
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Branch name to create |
| `--from REF` | No | `HEAD` | Base reference for new branch |
| `--checkout` | No | `true` | Checkout branch after create |
| `--no-checkout` | No | `false` | Create branch without checkout |
| `--push` | No | `false` | Push branch and set upstream |
| `--remote NAME` | No | `origin` | Remote for fetch/push |
| `--no-fetch` | No | `false` | Skip pre-create fetch |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Happy path: branch is created from target ref and checked out.
- Common operational path: create feature branch from `origin/main` and push with tracking.
- Failure path: invalid branch name or base ref not found.
- Recovery/rollback path: delete branch with `git/branch-delete.sh` or `git branch -d` and recreate.

## Usage
```bash
git/branch-create.sh --name feature/api-hardening --from origin/main --push
git/branch-create.sh --name hotfix/login-timeout --from release/1.4 --no-checkout
git/branch-create.sh --name chore/release-notes --dry-run
```

## Behavior
- Main execution flow:
  - validates repository context and branch name
  - optionally fetches remote refs
  - resolves base ref locally or as `remote/ref`
  - creates branch, optionally checks out and pushes upstream
- Idempotency notes: not idempotent for same branch name; fails if branch exists.
- Side effects: creates local branch; optionally switches HEAD and pushes remote branch.

## Output
- Standard output format: timestamped operational logs on stderr.
- Exit codes:
  - `0` success
  - `2` argument/validation failure
  - git command exit code for runtime failures

## Failure Modes
- Common errors and likely causes:
  - `invalid branch name`: branch violates git ref naming rules
  - `base reference not found`: typo or stale local refs
  - push failure: auth or remote policy restrictions
- Recovery and rollback steps:
  - verify ref with `git show-ref`
  - run with `--no-fetch` only when refs are known current
  - delete partially created branch and rerun with corrected inputs

## Security Notes
- Secret handling: script does not read/write secrets directly.
- Least-privilege requirements: standard repo write permissions only.
- Audit/logging expectations: branch creation and push are visible in git history/remote logs.

## Testing
- Unit tests:
  - invalid/missing argument validation
  - ref resolution behavior (`local`, `remote/ref`)
- Integration tests:
  - create from local and remote refs
  - create + push tracking branch
- Manual verification:
  - `git branch --list <name>` and `git rev-parse --abbrev-ref --symbolic-full-name @{upstream}`
