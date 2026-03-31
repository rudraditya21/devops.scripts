# verify.sh

## Purpose
Verify Kubernetes workstation tooling and kubeconfig readiness.

## Location
`setup/kube-workstation/verify.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: read access to kube config
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--strict` | No | `false` | Treat WARN as failure |
| `--json` | No | `false` | Emit JSON report |

## Usage
```bash
setup/kube-workstation/verify.sh
setup/kube-workstation/verify.sh --strict --json
```

## Behavior
- Checks `kubectl` and `helm` availability.
- Checks kubeconfig presence and current context.
- Emits PASS/WARN/FAIL summary.

## Output
- Table (default) or JSON report.
- Exit `1` on FAIL (or WARN in strict mode).

## Failure Modes
- Missing tooling.
- Missing kubeconfig/current context.

## Security Notes
- Reads config metadata only.

## Testing
- Validate strict and json modes locally.
