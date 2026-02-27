# create-cluster.sh

## Purpose
Create an EKS control-plane cluster with VPC endpoint settings, logging options, and tags.

## Location
`cloud/aws/eks/create-cluster.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `eks:CreateCluster`, `eks:DescribeCluster`, IAM role pass/use as required by EKS
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Cluster name |
| `--role-arn ARN` | Yes | N/A | EKS service role ARN |
| `--subnet-ids CSV` | Yes | N/A | At least 2 subnet IDs |
| `--security-group-ids CSV` | No | empty | Security groups for control plane ENIs |
| `--version VERSION` | No | AWS default | Kubernetes version |
| `--endpoint-public-access B` | No | `true` | Public endpoint enabled |
| `--endpoint-private-access B` | No | `false` | Private endpoint enabled |
| `--public-access-cidrs CSV` | No | empty | CIDR allow list for public endpoint |
| `--logging-types CSV` | No | empty | Enabled control plane log types |
| `--tag KEY=VALUE` / `--tags CSV` | No | empty | Cluster tags |
| `--if-not-exists` | No | `false` | Reuse existing cluster |
| `--wait` / `--no-wait` | No | wait enabled | Wait for ACTIVE |
| `--timeout SEC` | No | `1800` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Wait poll interval |
| `--region REGION`, `--profile PROFILE` | No | AWS defaults | AWS context override |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: cluster request succeeds and reaches `ACTIVE`.
- Common operational path: bootstrap EKS control plane before nodegroup provisioning.
- Failure path: IAM role invalid/not assumable, subnet/security group issues, or quota limits.
- Recovery/rollback path: inspect failed cluster events, fix infra/IAM constraints, re-run with corrected settings.

## Usage
```bash
cloud/aws/eks/create-cluster.sh --name prod-eks --role-arn arn:aws:iam::123456789012:role/eks-cluster-role --subnet-ids subnet-a,subnet-b
cloud/aws/eks/create-cluster.sh --name staging-eks --role-arn arn:aws:iam::123456789012:role/eks-cluster-role --subnet-ids subnet-a,subnet-b --logging-types api,audit --endpoint-private-access true
cloud/aws/eks/create-cluster.sh --name dev-eks --role-arn arn:aws:iam::123456789012:role/eks-cluster-role --subnet-ids subnet-a,subnet-b --if-not-exists --dry-run
```

## Behavior
- Main execution flow:
  - validates required identifiers and network inputs
  - optionally reuses existing cluster
  - submits `eks create-cluster` request with endpoint/logging/tag settings
  - optionally waits for `ACTIVE`
- Idempotency notes: convergent with `--if-not-exists`; otherwise existing cluster is an error.
- Side effects: creates managed EKS control plane resources.

## Output
- Standard output format: cluster name on stdout; operational logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/safety checks
  - non-zero AWS API/runtime failures

## Failure Modes
- Common errors and likely causes:
  - invalid role ARN or missing role trust/permissions
  - invalid subnet IDs or unsupported network layout
  - cluster already exists without reuse flag
- Recovery and rollback steps:
  - validate IAM role and trust policy for EKS
  - validate subnets/SGs and endpoint CIDR constraints
  - rerun with `--if-not-exists` in convergent automation paths

## Security Notes
- Secret handling: none.
- Least-privilege requirements: limit EKS/IAM permissions to cluster bootstrap scope.
- Audit/logging expectations: cluster creation and endpoint-access settings should be tracked in CloudTrail.

## Testing
- Unit tests:
  - argument parsing and CSV validation
  - endpoint/logging option composition
- Integration tests:
  - create cluster in sandbox and verify status transition
- Manual verification:
  - `aws eks describe-cluster --name <name>` status and endpoint settings
