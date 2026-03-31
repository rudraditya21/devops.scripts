# delete-cluster.sh

## Purpose
Delete an AKS cluster with explicit confirmation for live execution.

## Location
`cloud/azure/aks/delete-cluster.sh`

## Preconditions
- Required tools: `bash`, `az`
- Required permissions: AKS delete permissions in target resource group
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Cluster name |
| `--resource-group NAME` | Yes | N/A | Resource group |
| `--subscription ID` | No | az default | Subscription override |
| `--yes` | Cond. | `false` | Required unless `--dry-run` |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: remove retired AKS cluster after migration.
- Common operational path: teardown ephemeral environment cluster.
- Failure path: missing confirmation or insufficient delete permissions.
- Recovery/rollback path: redeploy cluster from IaC definitions.

## Usage
```bash
cloud/azure/aks/delete-cluster.sh --name aks-stg --resource-group rg-stg --yes
```

## Behavior
- Main execution flow:
  - validates required flags
  - enforces `--yes` in non-dry-run mode
  - executes `az aks delete --yes`
- Idempotency notes: destructive and non-idempotent.
- Side effects: removes AKS control plane and managed resources.

## Output
- Standard output format: native Azure CLI deletion output.
- Exit codes:
  - `0` success
  - `2` validation/confirmation errors
  - non-zero on API/auth failures

## Failure Modes
- Common errors and likely causes:
  - wrong resource-group context
  - cluster not found
  - missing delete rights
- Recovery and rollback steps:
  - confirm target identifiers
  - recreate cluster via deployment pipeline if needed

## Security Notes
- Secret handling: no secret output.
- Least-privilege requirements: delete permissions should be tightly scoped.
- Audit/logging expectations: deletion must be tied to approved change records.

## Testing
- Unit tests:
  - confirmation enforcement and option parsing
- Integration tests:
  - dry-run and real delete in non-production
- Manual verification:
  - verify cluster absence using `az aks show`/`az aks list`
