# sync-upload.sh

## Purpose
Synchronize local directories to S3 prefixes with production-safe upload options.

## Location
`cloud/aws/s3/sync-upload.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `s3:ListBucket`, `s3:PutObject`, optional `s3:DeleteObject` for `--delete`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--source PATH` | Yes | N/A | Local source directory |
| `--bucket NAME` | Yes | N/A | Target bucket |
| `--prefix PATH` | No | root | Target prefix |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default profile | AWS profile |
| `--delete` | No | `false` | Delete remote objects not in source |
| `--exclude PATTERN` | No | none | Exclude pattern (repeatable) |
| `--include PATTERN` | No | none | Include pattern (repeatable) |
| `--storage-class CLASS` | No | AWS default | Storage class override |
| `--sse MODE` | No | none | `AES256` or `aws:kms` |
| `--sse-kms-key-id ID` | No | none | KMS key (requires `--sse aws:kms`) |
| `--exact-timestamps` | No | `false` | Enforce exact timestamp comparison |
| `--no-progress` | No | `false` | Disable progress output |
| `--dry-run` | No | `false` | Simulate changes only |

## Scenarios
- Happy path: local artifacts are uploaded and converged to S3 prefix.
- Common operational path: deploy static assets/build outputs with controlled include/exclude patterns.
- Failure path: source path missing, permission denied, or wrong encryption settings.
- Recovery/rollback path: rerun from known-good source snapshot; optionally use versioning/object restore.

## Usage
```bash
cloud/aws/s3/sync-upload.sh --source dist --bucket org-prod-web --prefix web --delete
cloud/aws/s3/sync-upload.sh --source backups --bucket org-archive --storage-class STANDARD_IA
cloud/aws/s3/sync-upload.sh --source artifacts --bucket org-secure --sse aws:kms --sse-kms-key-id alias/app
```

## Behavior
- Main execution flow:
  - validates source directory and bucket input
  - builds `aws s3 sync` command with selected controls
  - executes or dry-runs sync
- Idempotency notes: convergent; repeat runs with same source/options should produce no changes.
- Side effects: uploads/updates/deletes S3 objects based on options.

## Output
- Standard output format: AWS sync output plus timestamped wrapper logs.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on AWS transfer/API failures

## Failure Modes
- Common errors and likely causes:
  - local path not found
  - KMS key mismatch/permission denial
  - network/API throttling or access denied
- Recovery and rollback steps:
  - fix local path/options and rerun
  - validate KMS/IAM policy and bucket policy alignment
  - use `--dry-run` before destructive `--delete` runs

## Security Notes
- Secret handling: do not sync secret files unintentionally; enforce exclude patterns.
- Least-privilege requirements: scope write/delete permissions to destination prefix.
- Audit/logging expectations: upload/delete events should be traceable via CloudTrail and S3 access logs.

## Testing
- Unit tests:
  - option validation and command assembly
- Integration tests:
  - sync with include/exclude, encryption, and delete modes in sandbox
- Manual verification:
  - compare local tree vs S3 object listing after sync
