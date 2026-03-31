# cluster-healthcheck.sh

## Purpose
Check AKS readiness: Azure CLI availability, account context, and optional cluster visibility.

## Location
`cloud/azure/aks/cluster-healthcheck.sh`

## Preconditions
- Required tools: `bash`, `az`
- Required permissions: account read and optional AKS read permissions
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | No | none | Optional cluster name |
| `--resource-group NAME` | Cond. | none | Required when `--name` is provided |
| `--subscription ID` | No | az default | Subscription override |
| `--strict` | No | `false` | WARN treated as failure |
| `--json` | No | `false` | JSON report output |

## Scenarios
- Happy path: account and optional cluster checks all pass.
- Common operational path: run before AKS lifecycle operations.
- Failure path: invalid login context or inaccessible cluster.
- Recovery/rollback path: re-authenticate and validate scope.

## Usage
```bash
cloud/azure/aks/cluster-healthcheck.sh --json
cloud/azure/aks/cluster-healthcheck.sh --name aks-stg --resource-group rg-stg --strict
```

## Behavior
- Main execution flow:
  - validates argument dependencies
  - checks `az` availability and active account
  - optionally verifies cluster provisioning state
  - prints PASS/WARN/FAIL summary
- Idempotency notes: read-only and safe to rerun.
- Side effects: none.

## Output
- Standard output format: table summary (default) or JSON.
- Exit codes:
  - `0` no failures (and no warnings in strict mode)
  - `1` failures detected (or warnings in strict mode)
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - az not installed
  - no active account/session
  - cluster inaccessible in provided scope
- Recovery and rollback steps:
  - run `az login`
  - set subscription with `az account set`
  - verify cluster name/resource-group pairing

## Security Notes
- Secret handling: no secret values emitted.
- Least-privilege requirements: read-only access for checks.
- Audit/logging expectations: check output should be retained in operational evidence.

## Testing
- Unit tests:
  - strict mode and flag dependency checks
- Integration tests:
  - run with and without target cluster
- Manual verification:
  - compare with `az account show` and `az aks show`
