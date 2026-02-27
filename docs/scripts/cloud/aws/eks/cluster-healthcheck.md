# cluster-healthcheck.sh

## Purpose
Assess EKS control-plane and nodegroup readiness, with optional kubectl node health checks.

## Location
`cloud/aws/eks/cluster-healthcheck.sh`

## Preconditions
- Required tools: `bash`, `aws` (and `kubectl` for kubectl checks)
- Required permissions: `eks:DescribeCluster`, `eks:ListNodegroups`, `eks:DescribeNodegroup`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cluster-name NAME` | Yes | N/A | Cluster name |
| `--require-nodegroups` | No | `false` | Fail when nodegroup count is zero |
| `--kubectl-check` | No | `false` | Include kubectl connectivity/node readiness checks |
| `--kubeconfig PATH` | No | default kubeconfig | Kubeconfig path for kubectl checks |
| `--max-unready-nodes N` | No | `0` | Allowed unready nodes |
| `--region REGION`, `--profile PROFILE` | No | AWS defaults | AWS context override |
| `--strict` | No | `false` | Fail on WARN status |
| `--json` | No | `false` | JSON output |

## Scenarios
- Happy path: cluster is ACTIVE, nodegroups healthy, optional node readiness within threshold.
- Common operational path: pre-deployment gate in CI/CD pipelines.
- Failure path: cluster unavailable, non-ACTIVE nodegroups, or kubectl connectivity failures.
- Recovery/rollback path: remediate cluster/nodegroup/network issues and rerun checks.

## Usage
```bash
cloud/aws/eks/cluster-healthcheck.sh --cluster-name prod-eks
cloud/aws/eks/cluster-healthcheck.sh --cluster-name prod-eks --require-nodegroups --strict
cloud/aws/eks/cluster-healthcheck.sh --cluster-name prod-eks --kubectl-check --kubeconfig ~/.kube/prod-config --max-unready-nodes 1 --json
```

## Behavior
- Main execution flow:
  - validates AWS CLI and cluster visibility
  - checks cluster status/version/endpoint access/OIDC
  - checks nodegroup count and ACTIVE status
  - optionally checks kubectl connectivity and unready node count
  - emits PASS/WARN/FAIL summary
- Idempotency notes: read-only diagnostics.
- Side effects: none.

## Output
- Standard output format: table by default, JSON with `--json`.
- Exit codes:
  - `0` no FAIL checks (and no WARN in strict mode)
  - `1` FAIL checks present or WARN in strict mode
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - cluster not found/inaccessible
  - nodegroups not ACTIVE
  - kubectl context/auth/network issues
- Recovery and rollback steps:
  - verify AWS account/region/profile
  - resolve nodegroup or control-plane issues
  - refresh kubeconfig and retry kubectl checks

## Security Notes
- Secret handling: no secret output; kubeconfig access should be controlled.
- Least-privilege requirements: read-only EKS permissions for healthcheck path.
- Audit/logging expectations: healthcheck results should be attached to deployment evidence.

## Testing
- Unit tests:
  - status aggregation and strict-mode behavior
- Integration tests:
  - healthy/unhealthy cluster fixtures in sandbox
- Manual verification:
  - compare output with direct `describe-cluster`/`describe-nodegroup` and kubectl node status
