# tag-release.sh

## Purpose
Create annotated release tags with semver validation, optional signing, and optional remote publication.

## Location
`git/tag-release.sh`

## Preconditions
- Required tools: `bash`, `git` (and `gpg` when `--sign`)
- Required permissions: local tag creation; remote tag push rights when `--push`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tag NAME` | Yes | N/A | Semver-like tag (`v1.2.3`) |
| `--ref REF` | No | `HEAD` | Commit/ref to tag |
| `--message TEXT` | No | `Release <tag>` | Tag annotation message |
| `--message-file PATH` | No | empty | Read annotation from file |
| `--sign` | No | `false` | Create signed tag |
| `--force` | No | `false` | Replace existing local tag |
| `--push` | No | `false` | Push tag to remote |
| `--remote NAME` | No | `origin` | Push remote |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Happy path: new annotated tag created and optionally pushed.
- Common operational path: tag the release commit and publish to origin.
- Failure path: tag already exists without `--force`, invalid semver format, or missing GPG.
- Recovery/rollback path: delete/recreate tag locally and remotely with controlled force.

## Usage
```bash
git/tag-release.sh --tag v1.6.0 --ref HEAD --push
git/tag-release.sh --tag v1.6.1-rc.1 --message "Release candidate 1"
git/tag-release.sh --tag v1.6.0 --force --dry-run
```

## Behavior
- Main execution flow:
  - validates tag format and target ref
  - checks existing tags and optional replacement path
  - creates annotated/signed tag
  - optionally pushes tag to selected remote
- Idempotency notes: idempotent only when same tag is not recreated; `--force` rewrites tag refs.
- Side effects: local tag creation/replacement and optional remote tag update.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` input/validation error
  - git command exit code for tag/push failures

## Failure Modes
- Common errors and likely causes:
  - invalid semver tag string
  - target ref does not exist
  - remote push blocked by permissions/policies
- Recovery and rollback steps:
  - fix input and rerun
  - remove incorrect tag and recreate
  - coordinate forced remote tag updates with release owners

## Security Notes
- Secret handling: signing uses local GPG private key material; protect keychain/agent.
- Least-privilege requirements: tag permissions only; avoid unnecessary branch write access.
- Audit/logging expectations: tag creation should map to release approvals/change records.

## Testing
- Unit tests:
  - semver and option validation
  - message/default behavior
- Integration tests:
  - create signed/unsigned tags on sample refs
  - push tag and verify remote existence
- Manual verification:
  - `git show <tag>` and remote tag listing
