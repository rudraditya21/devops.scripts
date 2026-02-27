# list-instances.sh

## Purpose
List EC2 instances with consistent filters and output modes suitable for operations and automation.

## Location
`cloud/aws/ec2/list-instances.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `ec2:DescribeInstances` in target region/account
- Required environment variables: none (AWS CLI credentials/profile must be configured)

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--region REGION` | No | AWS CLI default | AWS region override |
| `--profile PROFILE` | No | AWS CLI default | AWS profile override |
| `--state CSV` | No | `pending,running,stopping,stopped,shutting-down` | Instance state filter |
| `--tag KEY=VALUE` | No | none | Tag-based filter (repeatable) |
| `--id INSTANCE_ID` | No | none | Instance ID filter (repeatable) |
| `--ids CSV` | No | none | Comma-separated instance IDs |
| `--output MODE` | No | `table` | `table\|json\|ids` |
| `--include-terminated` | No | `false` | Include terminated instances in default listing |
| `--dry-run` | No | `false` | Print resolved AWS command only |

## Scenarios
- Happy path: operator lists active instances in region with readable table output.
- Common operational path: CI job requests instance IDs only for downstream lifecycle actions.
- Failure path: missing AWS credentials/profile or insufficient `DescribeInstances` permissions.
- Recovery/rollback path: validate AWS auth context (`aws sts get-caller-identity`) and rerun with correct region/profile.

## Usage
```bash
cloud/aws/ec2/list-instances.sh --region us-east-1
cloud/aws/ec2/list-instances.sh --state running --tag Environment=prod --output json
cloud/aws/ec2/list-instances.sh --ids i-0123456789abcdef0,i-0fedcba9876543210 --output ids
```

## Behavior
- Main execution flow:
  - validates AWS CLI availability and input syntax
  - builds `describe-instances` filters from state/tag/id selectors
  - emits output in `table`, `json`, or `ids` mode
- Idempotency notes: read-only and deterministic for same filters at a fixed point in time.
- Side effects: none.

## Output
- Standard output format:
  - `table`: AWS CLI table with core fields
  - `json`: structured instance objects
  - `ids`: space-separated instance IDs
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - AWS CLI non-zero exit on API/auth/permission failures

## Failure Modes
- Common errors and likely causes:
  - invalid instance ID format
  - malformed tag filter (`KEY=VALUE` required)
  - AWS API authorization failure
- Recovery and rollback steps:
  - fix argument format and rerun
  - verify profile/region and IAM policy for `ec2:DescribeInstances`

## Security Notes
- Secret handling: script does not print secrets; AWS credential handling remains in standard CLI config chain.
- Least-privilege requirements: read-only EC2 describe privileges.
- Audit/logging expectations: list operations should be traceable in CloudTrail.

## Testing
- Unit tests:
  - argument validation for IDs, tags, and output mode
  - filter construction correctness
- Integration tests:
  - run against test account with known instance/tag matrix
- Manual verification:
  - compare output with direct `aws ec2 describe-instances` query
