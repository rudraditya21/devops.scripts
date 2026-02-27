# delete-cluster.sh

## Purpose
Delete an EKS cluster safely, optionally deleting managed nodegroups first.

## Location
`cloud/aws/eks/delete-cluster.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `eks:DeleteCluster`, optional `eks:ListNodegroups`, `eks:DeleteNodegroup`, `eks:Describe*`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Cluster name |
| `--delete-nodegroups` | No | `false` | Delete all nodegroups before cluster delete |
| `--if-missing` | No | `false` | Return success if cluster absent |
| `--wait` / `--no-wait` | No | wait enabled | Wait for deletion |
| `--timeout SEC` | No | `1800` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Wait interval |
| `--region REGION`, `--profile PROFILE` | No | AWS defaults | AWS context override |
| `--yes` | Cond. | `false` | Required for non-dry-run deletion |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: nodegroups (optional) and cluster are deleted cleanly.
- Common operational path: ephemeral cluster teardown in integration environments.
- Failure path: deletion blocked by remaining resources or missing permissions.
- Recovery/rollback path: remove blockers manually, rerun deletion sequence.

## Usage
```bash
cloud/aws/eks/delete-cluster.sh --name dev-eks --yes
cloud/aws/eks/delete-cluster.sh --name dev-eks --delete-nodegroups --yes
cloud/aws/eks/delete-cluster.sh --name dev-eks --if-missing --dry-run
```

## Behavior
- Main execution flow:
  - validates cluster existence (or skip via `--if-missing`)
  - optionally deletes nodegroups first
  - submits cluster deletion request
  - optionally waits until cluster no longer exists
- Idempotency notes: convergent with `--if-missing`.
- Side effects: destructive removal of cluster control-plane resources.

## Output
- Standard output format: timestamped deletion logs.
- Exit codes:
  - `0` success
  - `2` invalid input or missing `--yes`
  - non-zero AWS API failures/timeouts

## Failure Modes
- Common errors and likely causes:
  - missing `--yes` safety confirmation
  - nodegroups not deleted when required by cluster state
  - IAM denies delete actions
- Recovery and rollback steps:
  - rerun with `--delete-nodegroups`
  - verify IAM permissions and retry
  - inspect EKS events and residual dependencies

## Security Notes
- Secret handling: none.
- Least-privilege requirements: destructive EKS permissions should be restricted to teardown roles.
- Audit/logging expectations: cluster teardown operations must be change-approved and auditable.

## Testing
- Unit tests:
  - safety guard and wait mode logic
- Integration tests:
  - teardown in disposable test clusters
- Manual verification:
  - `aws eks describe-cluster` returns not found post-delete
