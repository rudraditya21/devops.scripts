# stop-instance.sh

## Purpose
Stop one or more Compute Engine instances with optional wait for `TERMINATED` state.

## Location
`cloud/gcp/compute/stop-instance.sh`

## Preconditions
- Required tools: `bash`, `gcloud`, `awk`, `date`, `sleep`
- Required permissions: `compute.instances.stop`, `compute.instances.get`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Cond. | none | Instance name (repeatable) |
| `--names CSV` | Cond. | none | Comma-separated instance names |
| `--zone ZONE` | Yes | N/A | Instance zone |
| `--project PROJECT` | No | gcloud default | GCP project override |
| `--wait` | No | `true` | Wait for `TERMINATED` |
| `--no-wait` | No | `false` | Return after API call |
| `--timeout SEC` | No | `900` | Wait timeout |
| `--poll-interval SEC` | No | `10` | Poll interval |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: stop non-production VMs after business hours.
- Common operational path: stop multiple named VMs from an ops runbook.
- Failure path: invalid instance selection or missing permission.
- Recovery/rollback path: fix IAM/context and retry targeted stop.

## Usage
```bash
cloud/gcp/compute/stop-instance.sh --name app-vm-01 --zone us-central1-a
cloud/gcp/compute/stop-instance.sh --names app-vm-01,app-vm-02 --zone us-central1-a --no-wait
```

## Behavior
- Main execution flow:
  - validates input names and zone
  - issues `gcloud compute instances stop` per instance
  - optionally waits for `TERMINATED`
- Idempotency notes: repeated execution is safe for already-stopped instances.
- Side effects: powers off VM instances.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on gcloud/API or timeout failures

## Failure Modes
- Common errors and likely causes:
  - wrong zone/project context
  - denied stop permission
  - wait timeout
- Recovery and rollback steps:
  - verify project/zone and instance names
  - update IAM role bindings
  - re-run with increased timeout

## Security Notes
- Secret handling: no secret persistence.
- Least-privilege requirements: stop/get permissions scoped to target instances.
- Audit/logging expectations: stop actions should be traceable in Cloud Audit Logs.

## Testing
- Unit tests:
  - parsing and validation of repeated names
- Integration tests:
  - stop test VMs and validate final state
- Manual verification:
  - inspect status via `gcloud compute instances describe`
