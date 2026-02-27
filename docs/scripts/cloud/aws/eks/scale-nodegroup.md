# scale-nodegroup.sh

## Purpose
Update managed nodegroup scaling settings (`min`, `max`, `desired`) with safe validation.

## Location
`cloud/aws/eks/scale-nodegroup.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `eks:UpdateNodegroupConfig`, `eks:DescribeNodegroup`, `eks:DescribeUpdate`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cluster-name NAME` | Yes | N/A | Cluster name |
| `--nodegroup-name NAME` | Yes | N/A | Nodegroup name |
| `--min-size N` | Cond. | current | New min size |
| `--max-size N` | Cond. | current | New max size |
| `--desired-size N` | Cond. | current | New desired size |
| `--wait` / `--no-wait` | No | wait enabled | Wait for update completion |
| `--timeout SEC` | No | `1800` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION`, `--profile PROFILE` | No | AWS defaults | AWS context override |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: scaling update completes successfully.
- Common operational path: increase/decrease worker capacity based on workload demand.
- Failure path: invalid requested bounds or update failure.
- Recovery/rollback path: apply known-good scale values and retry update.

## Usage
```bash
cloud/aws/eks/scale-nodegroup.sh --cluster-name prod-eks --nodegroup-name general --desired-size 6
cloud/aws/eks/scale-nodegroup.sh --cluster-name prod-eks --nodegroup-name general --min-size 3 --max-size 12 --desired-size 6
cloud/aws/eks/scale-nodegroup.sh --cluster-name dev-eks --nodegroup-name general --desired-size 2 --dry-run
```

## Behavior
- Main execution flow:
  - loads current scaling config
  - merges requested values
  - validates final bounds
  - submits update and optionally waits for success
- Idempotency notes: convergent for same target scaling values.
- Side effects: node count scaling and related workload scheduling impact.

## Output
- Standard output format: update ID on stdout; logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/bound violations
  - non-zero on update failure or timeout

## Failure Modes
- Common errors and likely causes:
  - desired outside min/max
  - IAM denies update actions
  - nodegroup update conflicts/pending operations
- Recovery and rollback steps:
  - correct scaling inputs and retry
  - wait for existing updates to complete
  - inspect update error details via `describe-update`

## Security Notes
- Secret handling: none.
- Least-privilege requirements: update/read access limited to target nodegroups.
- Audit/logging expectations: scaling changes should map to autoscaling policy/change records.

## Testing
- Unit tests:
  - bounds validation and update payload construction
- Integration tests:
  - scale up/down in non-production nodegroups
- Manual verification:
  - compare desired/current sizes after update completion
