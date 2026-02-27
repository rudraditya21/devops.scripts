# upgrade-cluster.sh

## Purpose
Upgrade EKS control-plane Kubernetes version with optional forced path and update tracking.

## Location
`cloud/aws/eks/upgrade-cluster.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `eks:UpdateClusterVersion`, `eks:DescribeCluster`, `eks:DescribeUpdate`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Cluster name |
| `--version VERSION` | Yes | N/A | Target Kubernetes version |
| `--force` | No | `false` | Force upgrade when supported by EKS |
| `--wait` / `--no-wait` | No | wait enabled | Wait for update completion |
| `--timeout SEC` | No | `3600` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION`, `--profile PROFILE` | No | AWS defaults | AWS context override |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: update request succeeds and cluster returns `ACTIVE` at target version.
- Common operational path: scheduled cluster version increments before nodegroup/addon upgrades.
- Failure path: unsupported version jump, failed update, or timeout.
- Recovery/rollback path: review update errors, reconcile blockers, retry with validated target version.

## Usage
```bash
cloud/aws/eks/upgrade-cluster.sh --name prod-eks --version 1.31
cloud/aws/eks/upgrade-cluster.sh --name staging-eks --version 1.31 --force
cloud/aws/eks/upgrade-cluster.sh --name dev-eks --version 1.31 --dry-run
```

## Behavior
- Main execution flow:
  - validates cluster availability and current version
  - skips when already on target version
  - submits `update-cluster-version`
  - optionally waits for update success and cluster ACTIVE state
- Idempotency notes: re-running same target version is safe and exits without mutation.
- Side effects: control-plane version change.

## Output
- Standard output format: update ID on stdout; logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/preconditions
  - non-zero on AWS update failures/timeouts

## Failure Modes
- Common errors and likely causes:
  - invalid/unsupported target version
  - update status `Failed` or `Cancelled`
  - missing update permissions
- Recovery and rollback steps:
  - validate supported upgrade path and retry
  - inspect `describe-update` details and remediate
  - ensure addon/nodegroup compatibility before reattempt

## Security Notes
- Secret handling: none.
- Least-privilege requirements: EKS update/read permissions only.
- Audit/logging expectations: cluster version changes should be tied to change windows and approvals.

## Testing
- Unit tests:
  - argument and wait-control validation
- Integration tests:
  - upgrade non-production cluster across supported versions
- Manual verification:
  - `aws eks describe-cluster` shows target version and ACTIVE status
