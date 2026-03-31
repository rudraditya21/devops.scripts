# start-vm.sh

## Purpose
Start one or more Azure VMs and optionally wait until they are running.

## Location
`cloud/azure/vm/start-vm.sh`

## Preconditions
- Required tools: `bash`, `az`, `awk`, `date`, `sleep`
- Required permissions: `Microsoft.Compute/virtualMachines/start/action`, read access for instance view
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--resource-group NAME` | Yes | N/A | Resource group containing VMs |
| `--name NAME` | Cond. | none | VM name (repeatable) |
| `--names CSV` | Cond. | none | Comma-separated VM names |
| `--subscription ID` | No | az default | Subscription override |
| `--wait` | No | `true` | Wait for running state |
| `--no-wait` | No | `false` | Return immediately |
| `--timeout SEC` | No | `900` | Wait timeout |
| `--poll-interval SEC` | No | `10` | Poll interval |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: start application VMs before a deployment window.
- Common operational path: start a batch of VMs from CSV list.
- Failure path: wrong resource group or missing start permission.
- Recovery/rollback path: correct context and retry selected VMs.

## Usage
```bash
cloud/azure/vm/start-vm.sh --resource-group rg-app-prod --name vm-app-01
cloud/azure/vm/start-vm.sh --resource-group rg-app-prod --names vm-app-01,vm-app-02 --no-wait
```

## Behavior
- Main execution flow:
  - validates required scope and target names
  - runs `az vm start` per VM
  - optionally polls instance power state until `VM running`
- Idempotency notes: repeated starts are generally safe.
- Side effects: VM power state transitions to running.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` validation errors
  - non-zero on Azure CLI/API or timeout failures

## Failure Modes
- Common errors and likely causes:
  - invalid VM/resource-group pairing
  - denied start permissions
  - wait timeout during platform delays
- Recovery and rollback steps:
  - verify resource-group and subscription
  - verify role assignment for start action
  - rerun with higher timeout

## Security Notes
- Secret handling: no secret values accepted as flags.
- Least-privilege requirements: start + read instance-view permissions only.
- Audit/logging expectations: VM start operations should map to approved changes.

## Testing
- Unit tests:
  - list parsing and wait option handling
- Integration tests:
  - start stopped test VMs with wait/no-wait
- Manual verification:
  - inspect state with `az vm get-instance-view`
