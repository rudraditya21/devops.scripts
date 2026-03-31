# delete-cluster.sh

## Purpose
Delete a GKE cluster with explicit confirmation for non-dry-run execution.

## Location
`cloud/gcp/gke/delete-cluster.sh`

## Preconditions
- Required tools: `bash`, `gcloud`
- Required permissions: `container.clusters.delete`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Cluster name |
| `--zone ZONE` | Cond. | none | Zonal cluster location |
| `--region REGION` | Cond. | none | Regional cluster location |
| `--project PROJECT` | No | gcloud default | Project override |
| `--async` | No | `false` | Return after submit |
| `--yes` | Cond. | `false` | Required unless `--dry-run` |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: decommission obsolete cluster during environment teardown.
- Common operational path: async delete in CI cleanup jobs.
- Failure path: missing confirmation or invalid location context.
- Recovery/rollback path: recreate cluster from IaC if deleted unexpectedly.

## Usage
```bash
cloud/gcp/gke/delete-cluster.sh --name app-gke --zone us-central1-a --yes
cloud/gcp/gke/delete-cluster.sh --name app-gke --region us-central1 --async --yes
```

## Behavior
- Main execution flow:
  - validates required inputs and location flags
  - enforces `--yes` for destructive action
  - runs `gcloud container clusters delete --quiet`
- Idempotency notes: non-idempotent; cluster removal is destructive.
- Side effects: permanently deletes cluster resources.

## Output
- Standard output format: native gcloud deletion output.
- Exit codes:
  - `0` success
  - `2` argument/confirmation failures
  - non-zero from gcloud on API failures

## Failure Modes
- Common errors and likely causes:
  - `--yes` omitted
  - cluster not found in selected location
  - missing IAM delete permission
- Recovery and rollback steps:
  - confirm location and project
  - restore cluster through provisioning pipeline

## Security Notes
- Secret handling: no secret output.
- Least-privilege requirements: delete permission should be tightly scoped.
- Audit/logging expectations: deletion events must map to approved change tickets.

## Testing
- Unit tests:
  - location/confirmation validation
- Integration tests:
  - dry-run and real delete in non-production
- Manual verification:
  - confirm cluster absence in `gcloud container clusters list`
