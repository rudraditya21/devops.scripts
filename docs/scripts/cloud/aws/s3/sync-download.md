# sync-download.sh

## Purpose
Synchronize S3 bucket/prefix contents to local directories for restore, audit, or build workflows.

## Location
`cloud/aws/s3/sync-download.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `s3:ListBucket`, `s3:GetObject`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--bucket NAME` | Yes | N/A | Source bucket |
| `--prefix PATH` | No | root | Source prefix |
| `--dest PATH` | Yes | N/A | Local destination directory |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default profile | AWS profile |
| `--delete` | No | `false` | Delete local files not present in S3 source |
| `--exclude PATTERN` | No | none | Exclude pattern (repeatable) |
| `--include PATTERN` | No | none | Include pattern (repeatable) |
| `--exact-timestamps` | No | `false` | Enforce exact timestamp comparison |
| `--no-progress` | No | `false` | Disable progress output |
| `--dry-run` | No | `false` | Simulate changes only |

## Scenarios
- Happy path: S3 objects are downloaded and local path converges.
- Common operational path: restore deployment bundle/config snapshots from S3.
- Failure path: missing read permissions or wrong bucket/prefix.
- Recovery/rollback path: validate source path/profile and rerun with dry-run first.

## Usage
```bash
cloud/aws/s3/sync-download.sh --bucket org-prod-web --prefix releases/v1.2 --dest ./restore
cloud/aws/s3/sync-download.sh --bucket org-backups --dest ./backup --delete
cloud/aws/s3/sync-download.sh --bucket org-audit --prefix logs --dest ./logs --dry-run
```

## Behavior
- Main execution flow:
  - validates inputs and prepares destination directory
  - builds `aws s3 sync` with include/exclude/delete options
  - executes or dry-runs transfer
- Idempotency notes: convergent for fixed source/options.
- Side effects: local filesystem writes and optional deletions with `--delete`.

## Output
- Standard output format: AWS sync transfer logs plus wrapper timestamps.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on AWS/API/transfer failures

## Failure Modes
- Common errors and likely causes:
  - destination path permission issues
  - bucket/prefix not found
  - credential or policy mismatch
- Recovery and rollback steps:
  - ensure writable destination
  - verify account/region/profile
  - run without `--delete` to inspect deltas before destructive sync

## Security Notes
- Secret handling: downloaded artifacts may include sensitive data; protect local destination.
- Least-privilege requirements: read-only object access when possible.
- Audit/logging expectations: restore/download operations should be traceable in operational logs.

## Testing
- Unit tests:
  - option parsing and sync command assembly
- Integration tests:
  - sandbox download flows with include/exclude/delete modes
- Manual verification:
  - compare local files against source object listing/checksums
