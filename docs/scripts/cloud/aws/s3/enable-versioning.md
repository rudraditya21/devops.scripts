# enable-versioning.sh

## Purpose
Enable or suspend S3 bucket versioning with optional convergence waiting.

## Location
`cloud/aws/s3/enable-versioning.sh`

## Preconditions
- Required tools: `bash`, `aws`, `date`, `sleep`
- Required permissions: `s3:PutBucketVersioning`, `s3:GetBucketVersioning`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--bucket NAME` | Yes | N/A | Bucket name |
| `--status STATUS` | No | `Enabled` | `Enabled` or `Suspended` |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default profile | AWS profile |
| `--wait` | No | `true` | Wait for status convergence |
| `--no-wait` | No | `false` | Return immediately after API call |
| `--timeout SEC` | No | `120` | Wait timeout |
| `--poll-interval SEC` | No | `5` | Poll interval |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: bucket versioning transitions to target status.
- Common operational path: enabling versioning before lifecycle/replication controls.
- Failure path: missing versioning permissions or invalid bucket context.
- Recovery/rollback path: verify IAM and bucket ownership, then retry.

## Usage
```bash
cloud/aws/s3/enable-versioning.sh --bucket org-prod-data
cloud/aws/s3/enable-versioning.sh --bucket org-dev-data --status Suspended
cloud/aws/s3/enable-versioning.sh --bucket org-prod-data --no-wait --dry-run
```

## Behavior
- Main execution flow:
  - validates input and AWS context
  - applies requested versioning status
  - optionally polls until status matches
- Idempotency notes: repeat-safe for same requested status.
- Side effects: changes bucket object-version semantics.

## Output
- Standard output format: timestamped status logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on AWS API failures/timeouts

## Failure Modes
- Common errors and likely causes:
  - access denied on put/get versioning APIs
  - timeout due eventual-consistency delays
- Recovery and rollback steps:
  - recheck permissions and bucket policy
  - extend timeout and rerun

## Security Notes
- Secret handling: none.
- Least-privilege requirements: restrict versioning changes to admin/change roles.
- Audit/logging expectations: versioning state changes should align with data-protection controls.

## Testing
- Unit tests:
  - status/value validation and wait controls
- Integration tests:
  - enable/suspend transitions in sandbox buckets
- Manual verification:
  - `aws s3api get-bucket-versioning` status confirmation
