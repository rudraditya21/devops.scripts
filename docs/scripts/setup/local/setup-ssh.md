# setup-ssh.sh

## Purpose
Initialize SSH directory standards, key generation, and managed client defaults for reliable secure access.

## Location
`setup/local/setup-ssh.sh`

## Preconditions
- Required tools: `bash`, `ssh-keygen`, `chmod`
- Required permissions: write access to `~/.ssh`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--key-file PATH` | No | `~/.ssh/id_ed25519` | Private key path |
| `--email EMAIL` | No | `USER@HOST` | Key comment |
| `--key-type TYPE` | No | `ed25519` | `ed25519\|rsa` |
| `--rsa-bits N` | No | `4096` | RSA key length |
| `--no-generate-key` | No | `false` | Skip key creation |
| `--force-key` | No | `false` | Replace existing key |
| `--dry-run` | No | `false` | Print planned actions |

## Scenarios
- Happy path: `.ssh` permissions hardened, key exists, config block applied.
- Common operational path: first-time workstation bootstrap for Git/infra access.
- Failure path: key generation tool missing or write permission denied.
- Recovery/rollback path: remove broken key/config block and rerun with corrected options.

## Usage
```bash
setup/local/setup-ssh.sh --email "dev@example.com"
setup/local/setup-ssh.sh --key-type rsa --rsa-bits 4096 --force-key
setup/local/setup-ssh.sh --no-generate-key --dry-run
```

## Behavior
- Main execution flow: create/harden `.ssh`, optionally generate key, maintain managed `config` block.
- Idempotency notes: safe repeated execution without `--force-key`.
- Side effects: key material generation and config file updates.

## Output
- Standard output format: timestamped setup logs.
- Exit codes:
  - `0` success
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - invalid key type/bit values
  - inaccessible `~/.ssh`
  - missing `ssh-keygen`
- Recovery and rollback steps:
  - fix permissions/tools
  - regenerate keys with explicit options

## Security Notes
- Secret handling: private key stays local; ensure strict file permissions.
- Least-privilege requirements: user-level operations only.
- Audit/logging expectations: do not log private key contents.

## Testing
- Unit tests:
  - option validation and default selection
- Integration tests:
  - key generation and config merge behavior
- Manual verification:
  - `ssh -T`/Git host checks with generated key
