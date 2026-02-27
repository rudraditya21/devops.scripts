# set-lifecycle.sh

## Purpose
Apply lifecycle rules to an S3 bucket from a version-controlled JSON policy file.

## Location
`cloud/aws/s3/set-lifecycle.sh`

## Preconditions
- Required tools: `bash`, `aws` (optional `python3` for local JSON syntax validation)
- Required permissions: `s3:PutLifecycleConfiguration`, `s3:GetLifecycleConfiguration`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--bucket NAME` | Yes | N/A | Bucket name |
| `--file PATH` | Yes | N/A | Lifecycle JSON file |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default profile | AWS profile |
| `--validate-only` | No | `false` | Validate input and skip apply |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: lifecycle JSON is valid and applied successfully.
- Common operational path: policy rollout from Git-based config management.
- Failure path: invalid JSON, malformed rules, or permission denial.
- Recovery/rollback path: reapply previous known-good lifecycle file.

## Usage
```bash
cloud/aws/s3/set-lifecycle.sh --bucket org-prod-archive --file policies/lifecycle-prod.json
cloud/aws/s3/set-lifecycle.sh --bucket org-dev-archive --file policies/lifecycle-dev.json --validate-only
cloud/aws/s3/set-lifecycle.sh --bucket org-prod-archive --file policies/lifecycle-prod.json --dry-run
```

## Behavior
- Main execution flow:
  - validates input file presence and JSON syntax (when supported)
  - optionally validates-only without applying
  - applies lifecycle configuration via `put-bucket-lifecycle-configuration`
- Idempotency notes: repeat-safe for identical lifecycle policy input.
- Side effects: changes object expiration/transition behavior over time.

## Output
- Standard output format: timestamped apply/validation logs.
- Exit codes:
  - `0` success
  - `2` invalid arguments or invalid JSON input
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - invalid JSON schema/content for lifecycle rules
  - permission denied on lifecycle APIs
  - wrong bucket/account context
- Recovery and rollback steps:
  - fix policy file and rerun validation
  - restore prior lifecycle config from source control

## Security Notes
- Secret handling: policy files should not include secrets.
- Least-privilege requirements: lifecycle write permission restricted to controlled automation roles.
- Audit/logging expectations: lifecycle policy changes should be reviewed and tied to retention governance.

## Testing
- Unit tests:
  - argument checks and validation-only path
- Integration tests:
  - apply known lifecycle policies to sandbox buckets
- Manual verification:
  - `aws s3api get-bucket-lifecycle-configuration` comparison with source file
