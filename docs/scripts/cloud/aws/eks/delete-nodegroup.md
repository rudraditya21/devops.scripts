# delete-nodegroup.sh

## Purpose
Delete an EKS managed nodegroup with explicit confirmation and optional wait.

## Location
`cloud/aws/eks/delete-nodegroup.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `eks:DeleteNodegroup`, `eks:DescribeNodegroup`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cluster-name NAME` | Yes | N/A | Cluster name |
| `--nodegroup-name NAME` | Yes | N/A | Nodegroup name |
| `--if-missing` | No | `false` | Return success when missing |
| `--wait` / `--no-wait` | No | wait enabled | Wait for deletion completion |
| `--timeout SEC` | No | `1800` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION`, `--profile PROFILE` | No | AWS defaults | AWS context override |
| `--yes` | Cond. | `false` | Required for non-dry-run deletion |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: nodegroup deletion succeeds and resource is removed.
- Common operational path: remove outdated worker pools during migration/upgrade.
- Failure path: missing permissions or nodegroup busy/pending updates.
- Recovery/rollback path: recreate nodegroup or retry once conflicting updates clear.

## Usage
```bash
cloud/aws/eks/delete-nodegroup.sh --cluster-name prod-eks --nodegroup-name legacy-workers --yes
cloud/aws/eks/delete-nodegroup.sh --cluster-name dev-eks --nodegroup-name test-workers --if-missing --yes
cloud/aws/eks/delete-nodegroup.sh --cluster-name dev-eks --nodegroup-name test-workers --dry-run
```

## Behavior
- Main execution flow:
  - validates target and deletion confirmation
  - handles optional missing-resource skip
  - submits delete request
  - optionally waits until nodegroup disappears
- Idempotency notes: convergent with `--if-missing`.
- Side effects: worker capacity removal and workload eviction/rescheduling impact.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/safety guard failure
  - non-zero on AWS API failures/timeouts

## Failure Modes
- Common errors and likely causes:
  - missing `--yes` confirmation
  - nodegroup not found without `--if-missing`
  - delete denied or blocked by existing operations
- Recovery and rollback steps:
  - re-run with proper flags
  - wait for pending updates to complete
  - inspect EKS events and retry

## Security Notes
- Secret handling: none.
- Least-privilege requirements: deletion permission limited to approved principals.
- Audit/logging expectations: nodegroup deletions should be tracked with operational approvals.

## Testing
- Unit tests:
  - deletion safety checks and wait logic
- Integration tests:
  - delete nodegroup in disposable test cluster
- Manual verification:
  - `describe-nodegroup` returns not found
