# configure-git.sh

## Purpose
Apply consistent global Git configuration for identity, workflow defaults, and optional signing.

## Location
`setup/local/configure-git.sh`

## Preconditions
- Required tools: `bash`, `git`
- Required permissions: write access to global git config
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name VALUE` | No | unchanged | Set `user.name` |
| `--email VALUE` | No | unchanged | Set `user.email` |
| `--default-branch NAME` | No | `main` | Set `init.defaultBranch` |
| `--editor VALUE` | No | unchanged | Set `core.editor` |
| `--credential-helper V` | No | platform auto | Set `credential.helper` |
| `--rebase-pull BOOL` | No | `false` | Set `pull.rebase` |
| `--signing-key KEYID` | No | unchanged | Set `user.signingkey` |
| `--gpg-sign BOOL` | No | auto/unchanged | Set `commit.gpgsign` |
| `--dry-run` | No | `false` | Print planned changes |

## Scenarios
- Happy path: apply baseline global Git settings.
- Common operational path: bootstrap new workstation developer identity + defaults.
- Failure path: git unavailable or invalid boolean values.
- Recovery/rollback path: rerun with corrected values or reset keys via `git config --global --unset`.

## Usage
```bash
setup/local/configure-git.sh --name "Jane Doe" --email jane@example.com
setup/local/configure-git.sh --rebase-pull true --editor "code --wait"
setup/local/configure-git.sh --signing-key ABCD1234 --gpg-sign true --dry-run
```

## Behavior
- Main execution flow: validate options, set global git keys, optionally configure signing.
- Idempotency notes: idempotent; sets target values repeatedly.
- Side effects: modifies `~/.gitconfig`.

## Output
- Standard output format: timestamped status logs and dry-run command output.
- Exit codes:
  - `0` success
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - git not installed
  - invalid boolean input
- Recovery and rollback steps:
  - install git
  - pass boolean as true/false

## Security Notes
- Secret handling: no secret storage; consider secure credential helper backend.
- Least-privilege requirements: user-level git config operations.
- Audit/logging expectations: safe for bootstrap logs.

## Testing
- Unit tests:
  - boolean normalization and option parsing
- Integration tests:
  - dry-run vs apply behavior on test HOME
- Manual verification:
  - `git config --global --list` inspection
