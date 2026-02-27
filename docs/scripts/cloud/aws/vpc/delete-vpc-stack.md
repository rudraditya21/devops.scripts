# delete-vpc-stack.sh

## Purpose
Tear down VPC stack resources in safe dependency order and delete the VPC.

## Location
`cloud/aws/vpc/delete-vpc-stack.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: EC2 delete/detach/disassociate actions for NAT, routes, subnets, NACLs, security groups, IGWs, and VPC
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--vpc-id ID` | Yes | N/A | VPC to remove |
| `--if-missing` | No | `false` | Exit success if VPC does not exist |
| `--delete-internet-gateways` | No | `true` | Delete IGWs after detach |
| `--keep-internet-gateways` | No | `false` | Detach IGWs only |
| `--release-eips` | No | `false` | Release NAT-related EIPs after deletion |
| `--wait` / `--no-wait` | No | wait enabled | Wait for NAT deletion |
| `--timeout SEC` | No | `1800` | NAT deletion wait timeout |
| `--poll-interval SEC` | No | `15` | NAT deletion poll interval |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default | Profile override |
| `--yes` | Cond. | `false` | Required for non-dry-run deletion |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: NAT/RT/subnet/NACL/SG/IGW resources are removed and VPC deletion succeeds.
- Common operational path: cleanup of ephemeral integration/staging VPC stacks.
- Failure path: undeleted dependencies (ENIs/instances/endpoints) block VPC deletion.
- Recovery/rollback path: inspect residual resources, remove blockers, rerun teardown.

## Usage
```bash
cloud/aws/vpc/delete-vpc-stack.sh --vpc-id vpc-0123456789abcdef0 --yes
cloud/aws/vpc/delete-vpc-stack.sh --vpc-id vpc-0123456789abcdef0 --release-eips --yes
cloud/aws/vpc/delete-vpc-stack.sh --vpc-id vpc-0123456789abcdef0 --if-missing --dry-run
```

## Behavior
- Main execution flow:
  - validates VPC presence and confirmation guard
  - deletes NAT gateways (optional wait)
  - optionally releases EIPs
  - removes non-main route tables, subnets, non-default NACLs, non-default SGs
  - detaches/deletes IGWs based on mode
  - deletes VPC
- Idempotency notes: convergent with `--if-missing` and safe reruns after partial teardown.
- Side effects: destructive deletion of network resources.

## Output
- Standard output format: timestamped deletion logs on stderr.
- Exit codes:
  - `0` success
  - `2` safety/input failures
  - non-zero on AWS API failures/timeouts

## Failure Modes
- Common errors and likely causes:
  - missing `--yes` guard for live deletion
  - residual dependencies preventing deletion
  - denied delete permissions for one or more resource classes
- Recovery and rollback steps:
  - rerun in `--dry-run` to inspect action plan
  - manually remove blockers (instances/endpoints/ENIs)
  - rerun deletion with required IAM permissions

## Security Notes
- Secret handling: none.
- Least-privilege requirements: destructive permissions must be restricted to approved teardown roles.
- Audit/logging expectations: teardown events should map to ticketed lifecycle operations.

## Testing
- Unit tests:
  - option safety gates (`--yes`, `--if-missing`)
  - teardown ordering logic
- Integration tests:
  - controlled teardown in disposable sandbox VPC
- Manual verification:
  - confirm absence of VPC and child resources after run
