# start-instance.sh

## Purpose
Start one or more Compute Engine instances with optional wait for `RUNNING` state.

## Location
`cloud/gcp/compute/start-instance.sh`

## Preconditions
- Required tools: `bash`, `gcloud`, `awk`, `date`, `sleep`
- Required permissions: `compute.instances.start`, `compute.instances.get`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Cond. | none | Instance name (repeatable) |
| `--names CSV` | Cond. | none | Comma-separated instance names |
| `--zone ZONE` | Yes | N/A | Instance zone |
| `--project PROJECT` | No | gcloud default | GCP project override |
| `--wait` | No | `true` | Wait for `RUNNING` |
| `--no-wait` | No | `false` | Return after API call |
| `--timeout SEC` | No | `900` | Wait timeout |
| `--poll-interval SEC` | No | `10` | Poll interval |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: start maintenance-window VMs and wait for running state.
- Common operational path: start a small batch without waiting.
- Failure path: invalid instance name or missing start permission.
- Recovery/rollback path: inspect IAM and instance state, then retry.

## Usage
```bash
cloud/gcp/compute/start-instance.sh --name app-vm-01 --zone us-central1-a
cloud/gcp/compute/start-instance.sh --names app-vm-01,app-vm-02 --zone us-central1-a --no-wait
```

## Behavior
- Main execution flow:
  - validates input names and zone
  - issues `gcloud compute instances start` per instance
  - optionally polls until all instances are `RUNNING`
- Idempotency notes: safe repeat calls for already-running instances at API level.
- Side effects: powers on VM instances.

## Output
- Standard output format: timestamped status logs to stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on gcloud/API or timeout failures

## Failure Modes
- Common errors and likely causes:
  - invalid zone or instance name
  - denied `compute.instances.start`
  - wait timeout due boot delays
- Recovery and rollback steps:
  - validate zone/project
  - verify IAM permissions
  - increase timeout and re-run

## Security Notes
- Secret handling: no secret material handled.
- Least-privilege requirements: start/get permissions scoped to target instances.
- Audit/logging expectations: instance start events appear in Cloud Audit Logs.

## Testing
- Unit tests:
  - CSV parsing and name validation
- Integration tests:
  - start stopped test VMs with wait and no-wait modes
- Manual verification:
  - confirm instance status with `gcloud compute instances describe`
