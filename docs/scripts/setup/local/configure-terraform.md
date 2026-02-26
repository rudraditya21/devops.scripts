# configure-terraform.sh

## Purpose
Apply managed Terraform CLI configuration for plugin caching, checkpoint behavior, and optional registry credentials.

## Location
`setup/local/configure-terraform.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: write access to Terraform config and cache directories
- Required environment variables: optional `TF_TOKEN`

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--config-file PATH` | No | `~/.terraformrc` | Terraform CLI config path |
| `--plugin-cache-dir PATH` | No | `~/.terraform.d/plugin-cache` | Plugin cache directory |
| `--disable-checkpoint B` | No | `true` | `true\|false` checkpoint behavior |
| `--registry-host HOST` | No | `app.terraform.io` | Credentials host |
| `--token TOKEN` | No | from `TF_TOKEN` | Registry token |
| `--dry-run` | No | `false` | Show resulting managed config |

## Scenarios
- Happy path: managed Terraform block applied with plugin cache and defaults.
- Common operational path: set team-wide Terraform behavior on onboarding.
- Failure path: invalid boolean value or inaccessible config path.
- Recovery/rollback path: correct options and rerun, or remove managed block markers manually.

## Usage
```bash
setup/local/configure-terraform.sh
setup/local/configure-terraform.sh --plugin-cache-dir "$HOME/.cache/terraform/plugins"
setup/local/configure-terraform.sh --token "$TF_TOKEN" --registry-host app.terraform.io --dry-run
```

## Behavior
- Main execution flow: create config/cache paths, replace managed block in config file.
- Idempotency notes: managed block replacement is idempotent.
- Side effects: updates config file and creates plugin cache directory.

## Output
- Standard output format: timestamped status logs and config preview in dry-run mode.
- Exit codes:
  - `0` success
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - invalid `--disable-checkpoint` value
  - filesystem permission issues for config/cache paths
- Recovery and rollback steps:
  - fix option values
  - ensure directory ownership/permissions

## Security Notes
- Secret handling: token may be written in plaintext to Terraform config; restrict file permissions.
- Least-privilege requirements: user-level config writes.
- Audit/logging expectations: do not print token values in shared logs.

## Testing
- Unit tests:
  - boolean parsing and argument validation
- Integration tests:
  - managed block merge behavior with pre-existing config
- Manual verification:
  - run `terraform init` and confirm plugin cache usage
