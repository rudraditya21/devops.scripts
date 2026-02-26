# setup-shell.sh

## Purpose
Apply an idempotent managed block to shell rc files for consistent local shell environment setup.

## Location
`setup/local/setup-shell.sh`

## Preconditions
- Required tools: `bash`, `awk`
- Required permissions: write access to target rc file
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--shell NAME` | No | `auto` | `auto\|bash\|zsh` |
| `--rc-file PATH` | No | shell default rc | Explicit rc file path |
| `--prepend-path PATH` | No | `~/.local/bin` | Add managed path prepend (repeatable) |
| `--set-editor VALUE` | No | unset | Export `EDITOR` and `VISUAL` |
| `--set-pager VALUE` | No | unset | Export `PAGER` |
| `--dry-run` | No | `false` | Show resulting file content without writing |

## Scenarios
- Happy path: managed block is inserted/updated exactly once.
- Common operational path: standardize PATH/editor settings across engineers.
- Failure path: invalid shell option or filesystem write failure.
- Recovery/rollback path: remove managed block markers and rerun with corrected options.

## Usage
```bash
setup/local/setup-shell.sh --shell zsh --set-editor "code --wait" --set-pager less
setup/local/setup-shell.sh --prepend-path "$HOME/bin" --prepend-path "$HOME/.local/bin"
setup/local/setup-shell.sh --rc-file "$HOME/.bashrc" --dry-run
```

## Behavior
- Main execution flow: resolve rc target, strip old managed block, append refreshed block.
- Idempotency notes: managed block replacement is idempotent.
- Side effects: writes to shell rc file.

## Output
- Standard output format: timestamped status logs; rc content on `--dry-run`.
- Exit codes:
  - `0` success
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - invalid shell name
  - rc path inaccessible
- Recovery and rollback steps:
  - correct shell/rc options
  - ensure file ownership/permissions are correct

## Security Notes
- Secret handling: do not inject secret values into rc exports.
- Least-privilege requirements: user-level file writes only.
- Audit/logging expectations: track rc changes in dotfiles management where possible.

## Testing
- Unit tests:
  - rc path resolution and managed-block merge behavior
- Integration tests:
  - repeated runs produce stable file output
- Manual verification:
  - source rc file and confirm env/path behavior
