# stop-vm.sh

## Purpose
Stop or deallocate one or more Azure VMs with optional state convergence wait.

## Location
`cloud/azure/vm/stop-vm.sh`

## Preconditions
- Required tools: `bash`, `az`, `awk`, `date`, `sleep`
- Required permissions: stop/deallocate actions and VM instance-view read access
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--resource-group NAME` | Yes | N/A | Resource group containing VMs |
| `--name NAME` | Cond. | none | VM name (repeatable) |
| `--names CSV` | Cond. | none | Comma-separated VM names |
| `--subscription ID` | No | az default | Subscription override |
| `--deallocate` | No | `true` | Use deallocate action |
| `--no-deallocate` | No | `false` | Use stop action only |
| `--wait` | No | `true` | Wait for final state |
| `--no-wait` | No | `false` | Return immediately |
| `--timeout SEC` | No | `900` | Wait timeout |
| `--poll-interval SEC` | No | `10` | Poll interval |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: deallocate non-prod VMs to reduce cost.
- Common operational path: stop a maintenance pool before patching.
- Failure path: invalid scope or insufficient VM action permissions.
- Recovery/rollback path: restart VMs after correcting failed targets.

## Usage
```bash
cloud/azure/vm/stop-vm.sh --resource-group rg-app-prod --name vm-app-01
cloud/azure/vm/stop-vm.sh --resource-group rg-app-prod --names vm-app-01,vm-app-02 --no-deallocate
```

## Behavior
- Main execution flow:
  - validates VM target inputs
  - executes `az vm deallocate` or `az vm stop` per VM
  - optionally waits for expected display status
- Idempotency notes: repeatable for already stopped/deallocated VMs.
- Side effects: VM power state transitions to stopped/deallocated.

## Output
- Standard output format: timestamped operation logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on Azure CLI/API or timeout failures

## Failure Modes
- Common errors and likely causes:
  - wrong resource-group or VM name
  - denied stop/deallocate permission
  - timeout waiting for expected power state
- Recovery and rollback steps:
  - verify target VM scope
  - check role assignments
  - rerun with adjusted timeout

## Security Notes
- Secret handling: no secret arguments or outputs.
- Least-privilege requirements: stop/deallocate + read status only.
- Audit/logging expectations: stop operations should be logged in change records.

## Testing
- Unit tests:
  - option interaction (`--deallocate` vs `--no-deallocate`)
- Integration tests:
  - stop and deallocate test VMs
- Manual verification:
  - validate `PowerState` via Azure CLI
