# healthcheck.sh

## Purpose
Perform AWS EC2 environment health checks for automation readiness and permissions.

## Location
`cloud/aws/ec2/healthcheck.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: minimum read/identity checks (`sts:GetCallerIdentity`, EC2 describe APIs)
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--region REGION` | No | AWS CLI default | Region override for checks |
| `--profile PROFILE` | No | AWS CLI default | Profile override for checks |
| `--instance-id ID` | No | empty | Validate a specific instance visibility/state |
| `--strict` | No | `false` | Fail on warnings |
| `--json` | No | `false` | Output JSON report |

## Scenarios
- Happy path: all required checks pass and environment is ready for EC2 automation.
- Common operational path: preflight gate in CI/CD or local runbook execution.
- Failure path: missing AWS CLI, invalid credentials, or insufficient EC2 permissions.
- Recovery/rollback path: fix credentials/role bindings and rerun preflight before mutating operations.

## Usage
```bash
cloud/aws/ec2/healthcheck.sh
cloud/aws/ec2/healthcheck.sh --region us-east-1 --profile prod-readonly --json
cloud/aws/ec2/healthcheck.sh --instance-id i-0123456789abcdef0 --strict
```

## Behavior
- Main execution flow:
  - verifies AWS CLI availability
  - validates caller identity via STS
  - checks region config and core EC2 read permissions
  - reports inventory visibility and optional target instance state
  - returns pass/warn/fail summary
- Idempotency notes: read-only diagnostic behavior.
- Side effects: none.

## Output
- Standard output format:
  - table by default
  - JSON when `--json` is set
- Exit codes:
  - `0` no failures (and no warnings in strict mode)
  - `1` failures present, or warnings under strict mode
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - AWS CLI missing from PATH
  - invalid/expired credentials
  - blocked EC2 describe permissions
- Recovery and rollback steps:
  - renew credentials or assume correct role/profile
  - grant minimal required IAM read actions
  - rerun healthcheck before lifecycle scripts

## Security Notes
- Secret handling: no credential values are printed; only identity metadata and check results.
- Least-privilege requirements: keep to read-only permissions for preflight usage.
- Audit/logging expectations: preflight execution logs should be retained in deployment evidence.

## Testing
- Unit tests:
  - option parsing and status aggregation
  - JSON/text output shape validation
- Integration tests:
  - run under valid and intentionally restricted IAM contexts
- Manual verification:
  - compare reported identity and region with expected runtime context
