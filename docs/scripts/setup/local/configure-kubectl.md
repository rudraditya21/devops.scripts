# configure-kubectl.sh

## Purpose
Set local kubectl defaults (kubeconfig path, context, namespace) for safer and repeatable cluster operations.

## Location
`setup/local/configure-kubectl.sh`

## Preconditions
- Required tools: `bash`, `kubectl`
- Required permissions: write access to kubeconfig file/path
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--kubeconfig PATH` | No | `~/.kube/config` | Target kubeconfig file |
| `--context NAME` | No | unchanged | Context to select |
| `--namespace NAME` | No | unchanged | Namespace to set |
| `--dry-run` | No | `false` | Print commands without execution |

## Scenarios
- Happy path: context and namespace are configured successfully.
- Common operational path: enforce default namespace to avoid accidental cross-namespace actions.
- Failure path: missing kubectl or invalid context.
- Recovery/rollback path: run with valid context/namespace values and verify config.

## Usage
```bash
setup/local/configure-kubectl.sh --context prod-cluster --namespace platform
setup/local/configure-kubectl.sh --kubeconfig "$HOME/.kube/prod-config" --context prod
setup/local/configure-kubectl.sh --namespace default --dry-run
```

## Behavior
- Main execution flow: ensure kubeconfig path exists, apply context and namespace updates.
- Idempotency notes: idempotent for identical target settings.
- Side effects: modifies kubeconfig.

## Output
- Standard output format: timestamped logs and optional dry-run commands.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero from kubectl on command failure

## Failure Modes
- Common errors and likely causes:
  - kubectl missing
  - invalid context name
  - kubeconfig write permission issues
- Recovery and rollback steps:
  - validate context list (`kubectl config get-contexts`)
  - fix file permissions/path
  - rerun with corrected inputs

## Security Notes
- Secret handling: kubeconfig may contain credentials; keep file permissions strict.
- Least-privilege requirements: user-level config modifications only.
- Audit/logging expectations: avoid printing sensitive kubeconfig content.

## Testing
- Unit tests:
  - argument parsing and dry-run behavior
- Integration tests:
  - context/namespace changes on test kubeconfig
- Manual verification:
  - `kubectl config view --minify` output check
