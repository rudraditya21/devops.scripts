# create-nodegroup.sh

## Purpose
Create an EKS managed nodegroup with configurable scaling, capacity type, labels, and tags.

## Location
`cloud/aws/eks/create-nodegroup.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `eks:CreateNodegroup`, `eks:DescribeNodegroup`, `eks:DescribeCluster`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cluster-name NAME` | Yes | N/A | Cluster name |
| `--nodegroup-name NAME` | Yes | N/A | Nodegroup name |
| `--node-role-arn ARN` | Yes | N/A | Worker node IAM role ARN |
| `--subnet-ids CSV` | Yes | N/A | Subnet IDs for nodegroup |
| `--instance-types CSV` | No | AWS defaults | Node instance types |
| `--ami-type TYPE` | No | AWS default | Node AMI family |
| `--capacity-type TYPE` | No | `ON_DEMAND` | `ON_DEMAND\|SPOT` |
| `--disk-size GiB` | No | AWS default | Root volume size |
| `--min-size N` | No | `1` | Minimum nodes |
| `--max-size N` | No | `3` | Maximum nodes |
| `--desired-size N` | No | `2` | Desired nodes |
| `--labels CSV` | No | none | Node labels key=value |
| `--tag KEY=VALUE` / `--tags CSV` | No | none | Nodegroup tags |
| `--if-not-exists` | No | `false` | Reuse existing nodegroup |
| `--wait` / `--no-wait` | No | wait enabled | Wait for ACTIVE |
| `--timeout SEC` | No | `1800` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION`, `--profile PROFILE` | No | AWS defaults | AWS context override |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: nodegroup is created and reaches `ACTIVE`.
- Common operational path: add worker pool after control-plane creation.
- Failure path: invalid scaling bounds, invalid subnets/role, or insufficient capacity/quotas.
- Recovery/rollback path: delete failed nodegroup, fix config constraints, recreate.

## Usage
```bash
cloud/aws/eks/create-nodegroup.sh --cluster-name prod-eks --nodegroup-name general --node-role-arn arn:aws:iam::123456789012:role/eks-node-role --subnet-ids subnet-a,subnet-b
cloud/aws/eks/create-nodegroup.sh --cluster-name prod-eks --nodegroup-name spot-workers --node-role-arn arn:aws:iam::123456789012:role/eks-node-role --subnet-ids subnet-a,subnet-b --capacity-type SPOT --instance-types m6i.large,m6a.large
cloud/aws/eks/create-nodegroup.sh --cluster-name dev-eks --nodegroup-name general --node-role-arn arn:aws:iam::123456789012:role/eks-node-role --subnet-ids subnet-a,subnet-b --if-not-exists --dry-run
```

## Behavior
- Main execution flow:
  - validates cluster/nodegroup inputs and scaling bounds
  - optionally reuses existing nodegroup
  - submits create-nodegroup request with scaling/instance/label/tag options
  - optionally waits for ACTIVE status
- Idempotency notes: convergent with `--if-not-exists`.
- Side effects: creates nodegroup compute capacity and related AWS-managed resources.

## Output
- Standard output format: nodegroup name on stdout; logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/precondition failures
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - node role missing required EKS worker policies
  - invalid scaling bounds (`desired` outside `[min,max]`)
  - subnet/capacity constraints
- Recovery and rollback steps:
  - validate IAM node role and subnet reachability
  - correct scaling limits and rerun
  - inspect EKS nodegroup events for root cause

## Security Notes
- Secret handling: none.
- Least-privilege requirements: scoped EKS nodegroup create permissions.
- Audit/logging expectations: nodegroup creation and scaling parameters should be traceable.

## Testing
- Unit tests:
  - scaling validation and option assembly
- Integration tests:
  - create nodegroup in sandbox and validate ACTIVE transition
- Manual verification:
  - `aws eks describe-nodegroup` status/scaling details
