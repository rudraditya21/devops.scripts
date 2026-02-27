# public-access-block.sh

## Purpose
Manage S3 bucket Public Access Block settings with secure defaults and explicit modes.

## Location
`cloud/aws/s3/public-access-block.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `s3:PutBucketPublicAccessBlock`, `s3:GetBucketPublicAccessBlock`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--bucket NAME` | Yes | N/A | Bucket name |
| `--mode MODE` | No | `block` | `block\|allow\|custom` |
| `--block-public-acls BOOL` | No | mode-derived | Custom boolean override |
| `--ignore-public-acls BOOL` | No | mode-derived | Custom boolean override |
| `--block-public-policy BOOL` | No | mode-derived | Custom boolean override |
| `--restrict-public-buckets BOOL` | No | mode-derived | Custom boolean override |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default profile | AWS profile |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: bucket gets strict public access block settings.
- Common operational path: org-wide bucket hardening and compliance enforcement.
- Failure path: wrong profile/account or missing public-access-block permissions.
- Recovery/rollback path: apply explicit custom settings or switch mode after policy review.

## Usage
```bash
cloud/aws/s3/public-access-block.sh --bucket org-prod-data --mode block
cloud/aws/s3/public-access-block.sh --bucket org-static-site --mode allow
cloud/aws/s3/public-access-block.sh --bucket org-shared --block-public-policy true --restrict-public-buckets true
```

## Behavior
- Main execution flow:
  - validates bucket and mode/boolean inputs
  - resolves effective block configuration
  - applies configuration
  - reads back current configuration (non-dry-run)
- Idempotency notes: repeat-safe for same effective configuration.
- Side effects: modifies bucket-level public access behavior.

## Output
- Standard output format:
  - timestamped apply logs
  - AWS table output of effective `PublicAccessBlockConfiguration`
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - invalid boolean mode arguments
  - permission denial for public access block APIs
  - bucket ownership mismatch
- Recovery and rollback steps:
  - correct inputs and rerun
  - validate role/account context
  - reapply approved security baseline mode

## Security Notes
- Secret handling: none.
- Least-privilege requirements: restrict public access settings changes to security-admin roles.
- Audit/logging expectations: all public-access posture changes should be reviewed and auditable.

## Testing
- Unit tests:
  - boolean normalization and mode resolution
- Integration tests:
  - block/allow/custom transitions on sandbox buckets
- Manual verification:
  - compare read-back settings with intended policy baseline
