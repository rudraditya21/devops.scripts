# delete-bucket.sh

## Purpose
Delete S3 buckets safely, with optional forced purge of objects, versions, and multipart uploads.

## Location
`cloud/aws/s3/delete-bucket.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `s3:DeleteBucket`, optional object/version/multipart delete permissions for `--force`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--bucket NAME` | Yes | N/A | Bucket to delete |
| `--region REGION` | No | AWS config default | Region override |
| `--profile PROFILE` | No | AWS default profile | AWS profile |
| `--force` | No | `false` | Purge bucket contents before delete |
| `--if-exists` | No | `false` | Exit success if bucket missing/inaccessible |
| `--yes` | Cond. | `false` | Required for non-dry-run deletion |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: empty bucket deleted cleanly.
- Common operational path: force-delete versioned/temp buckets in controlled cleanup jobs.
- Failure path: bucket not empty without `--force`, or permission denied.
- Recovery/rollback path: stop job, restore from backups/versioned replicas if deletion was unintended.

## Usage
```bash
cloud/aws/s3/delete-bucket.sh --bucket org-dev-temp --yes
cloud/aws/s3/delete-bucket.sh --bucket org-old-artifacts --force --yes
cloud/aws/s3/delete-bucket.sh --bucket org-maybe-missing --if-exists --dry-run
```

## Behavior
- Main execution flow:
  - validates bucket and AWS context
  - verifies bucket accessibility
  - enforces explicit confirmation (`--yes`) for destructive execution
  - optional purge path removes objects/versions/delete markers/multipart uploads
  - calls `delete-bucket`
- Idempotency notes: idempotent with `--if-exists`; otherwise missing buckets error.
- Side effects: irreversible deletion of bucket data/metadata.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/safety gate failures
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - `BucketNotEmpty` when `--force` not provided
  - permission denied on version/multipart cleanup
  - bucket inaccessible due account mismatch
- Recovery and rollback steps:
  - rerun with proper force settings and approvals
  - validate account/role context before delete
  - restore required data from backup/source-of-truth systems

## Security Notes
- Secret handling: none.
- Least-privilege requirements: grant delete permissions only to approved cleanup roles.
- Audit/logging expectations: bucket deletion should require change approval and CloudTrail evidence.

## Testing
- Unit tests:
  - confirmation/safety flag validation
  - purge loop behavior for versions/multipart listings
- Integration tests:
  - delete empty and versioned buckets in sandbox
- Manual verification:
  - confirm bucket absence with `head-bucket` after execution
