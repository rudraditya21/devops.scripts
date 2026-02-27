# create-bucket.sh

## Purpose
Create an S3 bucket with optional tagging and versioning in a controlled, repeatable way.

## Location
`cloud/aws/s3/create-bucket.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `s3:CreateBucket`, optional `s3:PutBucketTagging`, `s3:PutBucketVersioning`
- Required environment variables: none (AWS credentials/profile must be configured)

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--bucket NAME` | Yes | N/A | Target bucket name |
| `--region REGION` | No | AWS config or `us-east-1` | Bucket region |
| `--profile PROFILE` | No | AWS default profile | AWS profile |
| `--tag KEY=VALUE` | No | none | Tag pair (repeatable) |
| `--tags CSV` | No | none | Comma-separated tag pairs |
| `--enable-versioning` | No | `false` | Enable versioning post-create |
| `--if-not-exists` | No | `false` | Exit success if bucket already exists/accessibly owned |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: bucket is created, tagged, and versioning enabled successfully.
- Common operational path: create environment-specific buckets in IaC bootstrap jobs.
- Failure path: name conflict, invalid name, or missing create permissions.
- Recovery/rollback path: validate naming/permissions, delete partial bucket if needed, rerun.

## Usage
```bash
cloud/aws/s3/create-bucket.sh --bucket org-prod-logs --region us-east-1 --enable-versioning
cloud/aws/s3/create-bucket.sh --bucket org-dev-artifacts --tag Environment=dev --tag Owner=platform
cloud/aws/s3/create-bucket.sh --bucket org-shared-cache --if-not-exists --dry-run
```

## Behavior
- Main execution flow:
  - validates bucket name and AWS CLI availability
  - resolves region fallback logic
  - checks bucket existence
  - creates bucket with region-aware API parameters
  - optionally applies tags and versioning
- Idempotency notes: idempotent when `--if-not-exists` is used for existing buckets.
- Side effects: new S3 bucket plus optional metadata/configuration changes.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/preconditions
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - bucket name already taken globally
  - region mismatch or invalid region
  - IAM policy denies create/tag/versioning actions
- Recovery and rollback steps:
  - pick globally unique name
  - validate region/profile context
  - grant least-privilege IAM actions and retry

## Security Notes
- Secret handling: no secret values are logged.
- Least-privilege requirements: scope permissions to required bucket actions only.
- Audit/logging expectations: bucket creation should be traceable in CloudTrail/change records.

## Testing
- Unit tests:
  - bucket-name/tag parsing validation
  - region fallback behavior
- Integration tests:
  - create with and without versioning/tags in sandbox account
- Manual verification:
  - `aws s3api head-bucket` and `get-bucket-versioning/get-bucket-tagging`
