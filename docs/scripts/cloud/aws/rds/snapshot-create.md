# snapshot-create.sh

## Purpose
Create a manual AWS RDS snapshot for backup, release checkpointing, or migration workflows.

## Location
`cloud/aws/rds/snapshot-create.sh`

## Preconditions
- Required tools: `bash`, `aws`, `awk`, `date`, `sleep`
- Required permissions: `rds:CreateDBSnapshot`, `rds:DescribeDBInstances`, `rds:DescribeDBSnapshots`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--identifier ID` | Yes | N/A | Source DB instance identifier |
| `--snapshot-id ID` | No | auto-generated | Snapshot identifier |
| `--tag KEY=VALUE` | No | none | Snapshot tag pair (repeatable) |
| `--tags CSV` | No | none | CSV tag list |
| `--wait` | No | `false` | Wait for `available` state |
| `--timeout SEC` | No | `7200` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION` | No | AWS config | Region override |
| `--profile PROFILE` | No | AWS config | Profile override |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: create manual backup before schema migration.
- Common operational path: capture release checkpoint snapshot before risky deploy.
- Failure path: duplicate snapshot identifier or missing DB instance.
- Recovery/rollback path: restore instance from the created snapshot.

## Usage
```bash
cloud/aws/rds/snapshot-create.sh --identifier app-prod-db-01 --wait

cloud/aws/rds/snapshot-create.sh \
  --identifier app-prod-db-01 \
  --snapshot-id app-prod-db-01-pre-migration-20260227 \
  --tag Change=INC-12345 \
  --tag Environment=prod
```

## Behavior
- Main execution flow:
  - validates input and confirms DB instance exists
  - ensures snapshot ID is not already present
  - calls `create-db-snapshot`
  - optionally waits for snapshot availability
  - prints snapshot identifier
- Idempotency notes: non-idempotent with generated IDs; explicit ID prevents duplicates.
- Side effects: creates additional snapshot storage cost.

## Output
- Standard output format:
  - stderr: timestamped logs
  - stdout: created `DBSnapshotIdentifier`
- Exit codes:
  - `0` success
  - `2` validation/precondition errors
  - non-zero on AWS/API/wait failures

## Failure Modes
- Common errors and likely causes:
  - snapshot identifier already in use
  - source DB not found
  - permission denial for snapshot creation
- Recovery and rollback steps:
  - choose unique snapshot ID
  - validate DB identifier and account/region context
  - retry after resolving IAM permission gaps

## Security Notes
- Secret handling: no plaintext secrets required.
- Least-privilege requirements: limit snapshot creation to backup/ops roles.
- Audit/logging expectations: snapshot naming should include change context.

## Testing
- Unit tests:
  - snapshot ID and tag parsing
- Integration tests:
  - create + wait in sandbox account
- Manual verification:
  - confirm snapshot status and tags in RDS console
