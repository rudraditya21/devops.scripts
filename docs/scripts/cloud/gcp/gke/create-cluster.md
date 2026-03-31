# create-cluster.sh

## Purpose
Create a GKE cluster with configurable location, node sizing, and network options.

## Location
`cloud/gcp/gke/create-cluster.sh`

## Preconditions
- Required tools: `bash`, `gcloud`
- Required permissions: `container.clusters.create`, network read/use permissions as needed
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Cluster name |
| `--zone ZONE` | Cond. | none | Zonal location |
| `--region REGION` | Cond. | none | Regional location |
| `--project PROJECT` | No | gcloud default | Project override |
| `--num-nodes N` | No | `3` | Node count |
| `--machine-type TYPE` | No | `e2-standard-4` | Node machine type |
| `--release-channel CHANNEL` | No | `regular` | `rapid\|regular\|stable` |
| `--network NAME` | No | default | VPC network |
| `--subnetwork NAME` | No | default | Subnetwork |
| `--async` | No | `false` | Return without waiting |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: create a regular-channel cluster for staging workloads.
- Common operational path: create regional cluster with custom machine type.
- Failure path: invalid location flags or missing cluster-create permissions.
- Recovery/rollback path: fix config/permissions and rerun.

## Usage
```bash
cloud/gcp/gke/create-cluster.sh --name app-gke --zone us-central1-a
cloud/gcp/gke/create-cluster.sh --name app-gke --region us-central1 --num-nodes 4 --machine-type e2-standard-8
```

## Behavior
- Main execution flow:
  - validates name and mutually exclusive location flags
  - assembles `gcloud container clusters create` command
  - executes or prints in dry-run mode
- Idempotency notes: not idempotent if cluster already exists.
- Side effects: provisions cluster control plane and nodes.

## Output
- Standard output format: native gcloud create output.
- Exit codes:
  - `0` success
  - `2` argument validation failure
  - non-zero from gcloud on API failures

## Failure Modes
- Common errors and likely causes:
  - both `--zone` and `--region` supplied
  - cluster name conflict
  - IAM/quota limits
- Recovery and rollback steps:
  - correct location flags
  - choose a unique name
  - request quota or adjust node sizing

## Security Notes
- Secret handling: no inline secrets.
- Least-privilege requirements: cluster creation and network usage permissions only.
- Audit/logging expectations: cluster create events should be linked to approved changes.

## Testing
- Unit tests:
  - location and release-channel validation
- Integration tests:
  - create a small non-prod cluster
- Manual verification:
  - verify cluster via `gcloud container clusters list`
