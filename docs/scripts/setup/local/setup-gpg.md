# setup-gpg.sh

## Purpose
Apply baseline GPG workstation setup and optional key/ownertrust imports for signing workflows.

## Location
`setup/local/setup-gpg.sh`

## Preconditions
- Required tools: `bash`, `gpg`, `gpgconf`, `awk`
- Required permissions: write access to `~/.gnupg`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--public-key FILE` | No | none | Import public key (repeatable) |
| `--private-key FILE` | No | none | Import private key (repeatable) |
| `--ownertrust FILE` | No | none | Import ownertrust data |
| `--default-key KEYID` | No | unset | Set default signing key |
| `--pinentry-program PATH` | No | unset | Set pinentry executable |
| `--dry-run` | No | `false` | Print planned actions/config |

## Scenarios
- Happy path: GPG home is secured and managed config applied.
- Common operational path: import team signing keys on new machine.
- Failure path: unreadable key files or missing `gpg` binary.
- Recovery/rollback path: correct inputs, re-import keys, reapply managed config.

## Usage
```bash
setup/local/setup-gpg.sh --default-key ABCD1234
setup/local/setup-gpg.sh --public-key ./pub.asc --private-key ./secret.asc
setup/local/setup-gpg.sh --pinentry-program /opt/homebrew/bin/pinentry-mac --dry-run
```

## Behavior
- Main execution flow: ensure `~/.gnupg` permissions, import inputs, update managed `gpg.conf`, launch agent.
- Idempotency notes: safe to rerun; imports may be no-op for existing keys.
- Side effects: updates keyring/ownertrust and gpg configuration files.

## Output
- Standard output format: timestamped setup logs and optional dry-run config output.
- Exit codes:
  - `0` success
  - `2` invalid arguments or unreadable inputs

## Failure Modes
- Common errors and likely causes:
  - missing `gpg` installation
  - unreadable key/ownertrust file
  - invalid config options
- Recovery and rollback steps:
  - verify file paths and permissions
  - reinstall/repair GPG tooling
  - rerun import/config commands

## Security Notes
- Secret handling: private key imports are sensitive; use secure local storage and cleanup.
- Least-privilege requirements: user-level keyring writes.
- Audit/logging expectations: avoid verbose logs that expose key metadata unnecessarily.

## Testing
- Unit tests:
  - option parsing and file validation
- Integration tests:
  - import behavior with test keyring
- Manual verification:
  - `gpg --list-secret-keys` and signing test
