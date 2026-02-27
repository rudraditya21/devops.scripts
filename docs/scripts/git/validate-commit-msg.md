# validate-commit-msg.sh

## Purpose
Validate commit messages against conventional commit structure and formatting constraints.

## Location
`git/validate-commit-msg.sh`

## Preconditions
- Required tools: `bash`, `head`
- Required permissions: read access to commit message file
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `COMMIT_MSG_FILE` | Yes | N/A | Path to commit message file |
| `--types CSV` | No | `feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert` | Allowed commit types |
| `--max-subject N` | No | `72` | Max subject length after prefix |
| `--max-body-line N` | No | `120` | Max body/footer line length |
| `--allow-merge-commits` | No | `false` | Accept `Merge ...` messages |

## Scenarios
- Happy path: commit header matches conventional format and limits.
- Common operational path: installed as `commit-msg` hook to gate local commits.
- Failure path: invalid type/scope format or missing blank separator line.
- Recovery/rollback path: edit message and retry commit/amend.

## Usage
```bash
git/validate-commit-msg.sh .git/COMMIT_EDITMSG
git/validate-commit-msg.sh --max-subject 80 --allow-merge-commits .git/COMMIT_EDITMSG
git/validate-commit-msg.sh --types feat,fix,chore .git/COMMIT_EDITMSG
```

## Behavior
- Main execution flow:
  - reads commit header
  - validates conventional pattern and allowed types
  - checks subject style/length
  - enforces blank line before body and body line-length constraints
- Idempotency notes: deterministic pure validation.
- Side effects: none.

## Output
- Standard output format: validation errors on stderr prefixed by `INVALID:`.
- Exit codes:
  - `0` valid message
  - `1` invalid commit message content
  - `2` invalid script usage/arguments

## Failure Modes
- Common errors and likely causes:
  - non-conventional header format
  - subject capitalization/punctuation violations
  - body line length exceeds configured maximum
- Recovery and rollback steps:
  - reword header to `type(scope): subject`
  - insert blank second line before body/footer
  - split long body lines

## Security Notes
- Secret handling: message files can include sensitive incident context; avoid exposing logs externally.
- Least-privilege requirements: read-only file access.
- Audit/logging expectations: validator failure logs are safe for local developer terminals.

## Testing
- Unit tests:
  - regex checks for valid/invalid headers
  - line-length enforcement
- Integration tests:
  - hook invocation from git `commit-msg`
- Manual verification:
  - run against sample valid and invalid messages
