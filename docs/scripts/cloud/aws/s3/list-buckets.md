# list-buckets.sh

## Purpose
List S3 buckets with optional prefix filter and optional per-bucket region enrichment.

## Location
`cloud/aws/s3/list-buckets.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `s3:ListAllMyBuckets`, optional `s3:GetBucketLocation` for `--with-region`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--region REGION` | No | AWS default | Region override for API calls |
| `--profile PROFILE` | No | AWS default profile | AWS profile |
| `--prefix TEXT` | No | none | Name prefix filter |
| `--with-region` | No | `false` | Include bucket region |
| `--output MODE` | No | `table` | `table\|json\|names` |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: operators list account buckets in table output.
- Common operational path: jobs fetch names only for downstream automation.
- Failure path: missing credentials or list permissions.
- Recovery/rollback path: validate AWS identity and retry with correct profile/role.

## Usage
```bash
cloud/aws/s3/list-buckets.sh
cloud/aws/s3/list-buckets.sh --prefix org-prod- --with-region --output json
cloud/aws/s3/list-buckets.sh --profile audit --output names
```

## Behavior
- Main execution flow:
  - queries bucket list
  - applies optional prefix filtering
  - optionally resolves each bucket location
  - renders selected output mode
- Idempotency notes: read-only and repeat-safe.
- Side effects: none.

## Output
- Standard output format: table/json/list of names depending on `--output`.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - missing `ListAllMyBuckets` permission
  - region lookup failure when `--with-region` and no location permission
- Recovery and rollback steps:
  - adjust IAM policy scope
  - rerun without region enrichment when not required

## Security Notes
- Secret handling: none.
- Least-privilege requirements: read-only S3 listing/location permissions.
- Audit/logging expectations: account-wide inventory listing should be run from approved ops roles.

## Testing
- Unit tests:
  - output-mode and prefix-filter handling
- Integration tests:
  - list output across profiles/accounts in sandbox
- Manual verification:
  - compare against `aws s3api list-buckets` direct output
