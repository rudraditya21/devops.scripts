# tag-instance.sh

## Purpose
Apply standardized tags to EC2 instances, with optional add-only behavior for missing keys.

## Location
`cloud/aws/ec2/tag-instance.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `ec2:CreateTags`, `ec2:DescribeTags`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--id INSTANCE_ID` | Cond. | none | Instance ID (repeatable) |
| `--ids CSV` | Cond. | none | Comma-separated instance IDs |
| `--tag KEY=VALUE` | Cond. | none | Tag pair (repeatable) |
| `--tags CSV` | Cond. | none | Comma-separated tag pairs |
| `--if-missing` | No | `false` | Add keys only when absent on each instance |
| `--region REGION` | No | AWS CLI default | AWS region override |
| `--profile PROFILE` | No | AWS CLI default | AWS profile override |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: governance tags applied consistently to all targeted instances.
- Common operational path: bulk tag updates during onboarding or cost-allocation enforcement.
- Failure path: invalid tag syntax or missing tag write permissions.
- Recovery/rollback path: reapply previous tag set from source-of-truth inventory.

## Usage
```bash
cloud/aws/ec2/tag-instance.sh --id i-0123456789abcdef0 --tag Environment=prod --tag Owner=platform
cloud/aws/ec2/tag-instance.sh --ids i-0123456789abcdef0,i-0fedcba9876543210 --tags CostCenter=1234,Service=api
cloud/aws/ec2/tag-instance.sh --id i-0123456789abcdef0 --tag Backup=true --if-missing
```

## Behavior
- Main execution flow:
  - validates instance IDs and tag pair syntax
  - optionally discovers existing keys per instance (`--if-missing`)
  - applies tags via `create-tags`
- Idempotency notes: standard mode overwrites supplied keys; `--if-missing` preserves existing keys.
- Side effects: metadata changes on target EC2 resources.

## Output
- Standard output format: timestamped tagging logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero AWS/API failure

## Failure Modes
- Common errors and likely causes:
  - malformed tag expression
  - unauthorized tagging action
  - instance/resource lookup failures in wrong region/account
- Recovery and rollback steps:
  - fix syntax and rerun
  - validate IAM policy scope and AWS context
  - reapply desired tag catalog from CMDB/source repository

## Security Notes
- Secret handling: avoid placing secrets or tokens in tag values.
- Least-privilege requirements: scoped tag write/read permissions.
- Audit/logging expectations: tag mutations should be visible in CloudTrail and governance reviews.

## Testing
- Unit tests:
  - parsing and validation of tag pairs
  - `--if-missing` selection logic
- Integration tests:
  - bulk tag updates in sandbox account
- Manual verification:
  - inspect final tags with `describe-tags` or EC2 console
