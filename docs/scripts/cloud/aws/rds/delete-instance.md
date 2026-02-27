# delete-instance.sh

## Purpose
Delete an AWS RDS DB instance with controlled final-snapshot behavior and optional deletion wait.

## Location
`cloud/aws/rds/delete-instance.sh`

## Preconditions
- Required tools: `bash`, `aws`, `date`, `sleep`, `grep`
- Required permissions: `rds:DeleteDBInstance`, `rds:DescribeDBInstances`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--identifier ID` | Yes | N/A | DB instance identifier to delete |
| `--skip-final-snapshot` | No | `false` | Skip final snapshot (destructive) |
| `--final-snapshot-id ID` | No | auto-generated | Final snapshot ID when snapshot is enabled |
| `--delete-automated-backups` | No | `true` | Remove retained automated backups |
| `--retain-automated-backups` | No | `false` | Keep retained automated backups |
| `--wait` | No | `false` | Wait until instance is fully deleted |
| `--timeout SEC` | No | `7200` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION` | No | AWS config | Region override |
| `--profile PROFILE` | No | AWS config | Profile override |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: delete decommissioned instance while preserving a final snapshot.
- Common operational path: remove temporary environments to reduce cost.
- Failure path: instance not found or snapshot identifier conflict.
- Recovery/rollback path: restore from the final snapshot into a replacement instance.

## Usage
```bash
cloud/aws/rds/delete-instance.sh --identifier app-stg-db-01 --wait

cloud/aws/rds/delete-instance.sh \
  --identifier app-dev-db-01 \
  --skip-final-snapshot \
  --delete-automated-backups
```

## Behavior
- Main execution flow:
  - validates instance existence
  - enforces snapshot flag compatibility
  - auto-generates final snapshot ID when needed
  - calls `delete-db-instance`
  - optionally waits for `DBInstanceNotFound`
- Idempotency notes: safe to rerun with `--wait` while resource is in `deleting` state.
- Side effects: permanently removes DB instance; snapshot retention depends on flags.

## Output
- Standard output format:
  - stderr: timestamped logs and deletion progress
- Exit codes:
  - `0` success
  - `2` validation/precondition errors
  - non-zero on AWS/API/wait errors

## Failure Modes
- Common errors and likely causes:
  - final snapshot ID collision
  - insufficient IAM permissions
  - deletion blocked by dependent operations
- Recovery and rollback steps:
  - provide unique `--final-snapshot-id`
  - wait for pending operations to complete
  - restore deleted instance from snapshot if needed

## Security Notes
- Secret handling: no secret arguments required.
- Least-privilege requirements: restrict delete permissions to approved operators.
- Audit/logging expectations: deletions should be linked to approved change requests.

## Testing
- Unit tests:
  - snapshot flag conflict validation
  - generated snapshot identifier format
- Integration tests:
  - delete with and without final snapshot in non-prod account
- Manual verification:
  - verify instance absence and snapshot presence in RDS console
