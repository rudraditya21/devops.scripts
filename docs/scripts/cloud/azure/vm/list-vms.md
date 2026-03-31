# list-vms.sh

## Purpose
List Azure virtual machines with optional resource-group scope and output modes.

## Location
`cloud/azure/vm/list-vms.sh`

## Preconditions
- Required tools: `bash`, `az`
- Required permissions: `Microsoft.Compute/virtualMachines/read`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--resource-group NAME` | No | all groups | Restrict listing scope |
| `--subscription ID` | No | az default | Subscription override |
| `--output MODE` | No | `table` | `table\|json\|names` |
| `--show-details` | No | `false` | Include power-state/IP fields |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: list all VMs in the active subscription.
- Common operational path: list names from one resource group for batch actions.
- Failure path: missing az CLI or no read permissions.
- Recovery/rollback path: fix account/subscription context and rerun.

## Usage
```bash
cloud/azure/vm/list-vms.sh --resource-group rg-app-prod
cloud/azure/vm/list-vms.sh --output names --show-details
```

## Behavior
- Main execution flow:
  - validates options
  - builds `az vm list` command with optional scoping
  - renders output as table/json/names
- Idempotency notes: read-only operation.
- Side effects: none.

## Output
- Standard output format: native Azure CLI formatted output.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero from Azure CLI on auth/API errors

## Failure Modes
- Common errors and likely causes:
  - invalid output mode
  - inactive Azure login/session
  - insufficient reader permissions
- Recovery and rollback steps:
  - run `az login`
  - set subscription with `az account set`
  - verify role assignment

## Security Notes
- Secret handling: no secret arguments logged.
- Least-privilege requirements: VM read permissions only.
- Audit/logging expectations: listing actions should align with support runbooks.

## Testing
- Unit tests:
  - output-mode and flag parsing
- Integration tests:
  - list in test subscription/resource-group
- Manual verification:
  - compare results with direct `az vm list`
