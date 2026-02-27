# rds-healthcheck.sh

## Purpose
Run a readiness and posture check for AWS RDS automation, including auth, permissions, and optional instance-level controls.

## Location
`cloud/aws/rds/rds-healthcheck.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `sts:GetCallerIdentity`, `rds:DescribeDBInstances`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--region REGION` | No | AWS config | Region override |
| `--profile PROFILE` | No | AWS config | Profile override |
| `--instance-id ID` | No | empty | Run targeted posture checks for one instance |
| `--strict` | No | `false` | Treat WARN as failure |
| `--json` | No | `false` | Emit JSON report |

## Scenarios
- Happy path: CI runner validates AWS access and RDS visibility before deploy.
- Common operational path: on-call runs healthcheck before incident remediation.
- Failure path: missing AWS CLI, auth failure, or denied describe permissions.
- Recovery/rollback path: fix credentials/policy/region and rerun to confirm green checks.

## Usage
```bash
cloud/aws/rds/rds-healthcheck.sh --region us-east-1

cloud/aws/rds/rds-healthcheck.sh --instance-id app-prod-db-01 --strict

cloud/aws/rds/rds-healthcheck.sh --json > rds-healthcheck.json
```

## Behavior
- Main execution flow:
  - checks AWS CLI presence
  - validates STS identity
  - checks region config and RDS describe permission
  - reports visible DB instance count
  - if `--instance-id` is set, checks status, encryption, backup retention, and deletion protection
- Idempotency notes: read-only; safe to run repeatedly.
- Side effects: none (read-only AWS API calls).

## Output
- Standard output format:
  - text table by default
  - JSON object when `--json` is used
- Exit codes:
  - `0` no failures (`WARN` allowed unless `--strict`)
  - `1` one or more `FAIL` checks or `WARN` in strict mode
  - `2` argument validation failure

## Failure Modes
- Common errors and likely causes:
  - `auth:sts` FAIL when credentials/session are invalid
  - permission check FAIL when IAM policy lacks `rds:DescribeDBInstances`
  - instance-level FAIL when identifier is wrong or inaccessible
- Recovery and rollback steps:
  - refresh AWS credentials/session
  - add least-privilege describe permissions
  - verify identifier/region/account context

## Security Notes
- Secret handling: does not print secret material; reports only account/ARN and control posture.
- Least-privilege requirements: read-only permissions are sufficient for this script.
- Audit/logging expectations: use JSON mode in CI for archived compliance traces.

## Testing
- Unit tests:
  - JSON escaping and status aggregation
  - identifier validation
- Integration tests:
  - run against sandbox account with and without targeted instance
- Manual verification:
  - compare script result with RDS console configuration fields
