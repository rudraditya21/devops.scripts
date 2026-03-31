# verify.sh

## Purpose
Verify security toolchain readiness (`gpg`, `ssh`, `openssl`) and key config directories.

## Location
`setup/security-tools/verify.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: read access to user home config dirs
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--strict` | No | `false` | Treat WARN as failure |
| `--json` | No | `false` | Emit JSON report |

## Usage
```bash
setup/security-tools/verify.sh
setup/security-tools/verify.sh --strict --json
```

## Behavior
- Checks command availability and security config directory presence.

## Output
- PASS/WARN/FAIL summary in table or JSON form.

## Failure Modes
- Missing security binaries.
- Missing `~/.ssh` or `~/.gnupg` directories.

## Security Notes
- Reports metadata only, not key material.

## Testing
- Run on hosts with partial tooling installations.
