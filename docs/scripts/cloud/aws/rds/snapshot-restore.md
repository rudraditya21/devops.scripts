# snapshot-restore.sh

## Purpose
Restore an AWS RDS DB instance from a snapshot with network and safety controls.

## Location
`cloud/aws/rds/snapshot-restore.sh`

## Preconditions
- Required tools: `bash`, `aws`, `awk`, `date`, `sleep`
- Required permissions: `rds:RestoreDBInstanceFromDBSnapshot`, `rds:DescribeDBSnapshots`, `rds:DescribeDBInstances`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--snapshot-id ID` | Yes | N/A | Source snapshot identifier |
| `--identifier ID` | Yes | N/A | Target DB instance identifier |
| `--instance-class CLASS` | No | snapshot source default | Instance class override |
| `--port PORT` | No | snapshot source/default | Port override |
| `--availability-zone AZ` | No | AWS chosen | Availability zone preference |
| `--db-subnet-group NAME` | No | source/default | DB subnet group |
| `--vpc-security-group-id SG` | No | none | Security group ID (repeatable) |
| `--vpc-security-group-ids CSV` | No | none | CSV security group IDs |
| `--storage-type TYPE` | No | source/default | Storage override |
| `--multi-az` / `--no-multi-az` | No | unchanged | Multi-AZ behavior |
| `--publicly-accessible` / `--no-publicly-accessible` | No | unchanged | Public access behavior |
| `--copy-tags-to-snapshot` / `--no-copy-tags-to-snapshot` | No | `--copy-tags-to-snapshot` | Future snapshot tag propagation |
| `--deletion-protection` / `--no-deletion-protection` | No | `--deletion-protection` | Deletion guard |
| `--wait` | No | `false` | Wait for restored instance availability |
| `--timeout SEC` | No | `7200` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION` | No | AWS config | Region override |
| `--profile PROFILE` | No | AWS config | Profile override |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: restore production backup into controlled target environment.
- Common operational path: create staging clone from latest approved snapshot.
- Failure path: snapshot unavailable or target instance identifier already exists.
- Recovery/rollback path: clean failed restore and rerun with corrected network/class options.

## Usage
```bash
cloud/aws/rds/snapshot-restore.sh \
  --snapshot-id app-prod-db-01-pre-migration-20260227 \
  --identifier app-prod-db-restore-01 \
  --instance-class db.t3.large \
  --db-subnet-group app-prod-db-subnets \
  --vpc-security-group-ids sg-0123456789abcdef0 \
  --wait
```

## Behavior
- Main execution flow:
  - validates source snapshot exists and is `available`
  - validates target identifier does not already exist
  - builds restore command with optional network/storage/safety flags
  - optionally waits until restored instance is `available`
  - prints restored DB identifier
- Idempotency notes: not idempotent with same target identifier once restore starts.
- Side effects: creates a new billable DB instance from snapshot data.

## Output
- Standard output format:
  - stderr: timestamped logs
  - stdout: restored `DBInstanceIdentifier`
- Exit codes:
  - `0` success
  - `2` validation/precondition errors
  - non-zero on AWS/API/wait failures

## Failure Modes
- Common errors and likely causes:
  - snapshot status not `available`
  - target identifier collision
  - invalid subnet/security group references
- Recovery and rollback steps:
  - wait for snapshot completion and retry
  - choose a new identifier
  - correct network settings and rerun

## Security Notes
- Secret handling: no master password exposure during snapshot restore.
- Least-privilege requirements: restrict restore permissions in production accounts.
- Audit/logging expectations: restore actions should be mapped to incidents/tests/changes.

## Testing
- Unit tests:
  - identifier and state validation
  - option parsing for networking/safety flags
- Integration tests:
  - restore + wait in isolated account
- Manual verification:
  - verify instance reachability, encryption, and deletion protection settings
