# list-instances.sh

## Purpose
List Google Compute Engine instances with optional filters and selectable output modes.

## Location
`cloud/gcp/compute/list-instances.sh`

## Preconditions
- Required tools: `bash`, `gcloud`
- Required permissions: `compute.instances.list`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--project PROJECT` | No | gcloud default | GCP project override |
| `--zone ZONE` | No | all zones | Zone filter (repeatable) |
| `--state STATE` | No | all states | State filter (repeatable) |
| `--name NAME` | No | all names | Instance name filter (repeatable) |
| `--output MODE` | No | `table` | `table\|json\|names` |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: list instances for a project in table format.
- Common operational path: filter by zone and running state during incident triage.
- Failure path: missing gcloud binary or denied IAM permission.
- Recovery/rollback path: fix auth/project context and rerun.

## Usage
```bash
cloud/gcp/compute/list-instances.sh --project prod-project --zone us-central1-a
cloud/gcp/compute/list-instances.sh --state RUNNING --output names
```

## Behavior
- Main execution flow:
  - validates CLI arguments
  - builds `gcloud compute instances list` command
  - applies optional filters and output format
- Idempotency notes: read-only operation.
- Side effects: none.

## Output
- Standard output format: selected `gcloud` format (`table`, `json`, or newline names).
- Exit codes:
  - `0` success
  - `2` invalid arguments or missing prerequisites
  - non-zero from `gcloud` on API/auth failures

## Failure Modes
- Common errors and likely causes:
  - invalid output mode value
  - gcloud not installed
  - unauthorized project access
- Recovery and rollback steps:
  - install/authenticate gcloud
  - set or pass correct project
  - verify IAM role allows list operations

## Security Notes
- Secret handling: no secrets printed or persisted.
- Least-privilege requirements: read-only Compute list permission.
- Audit/logging expectations: use Cloud Audit Logs for API access review.

## Testing
- Unit tests:
  - argument parsing and output-mode validation
- Integration tests:
  - run against test project with multiple zones
- Manual verification:
  - compare output with `gcloud compute instances list`
