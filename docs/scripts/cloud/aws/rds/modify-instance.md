# modify-instance.sh

## Purpose
Apply controlled mutable configuration changes to an existing AWS RDS DB instance.

## Location
`cloud/aws/rds/modify-instance.sh`

## Preconditions
- Required tools: `bash`, `aws`, `date`, `sleep`
- Required permissions: `rds:ModifyDBInstance`, `rds:DescribeDBInstances`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--identifier ID` | Yes | N/A | DB instance identifier |
| `--instance-class CLASS` | No | unchanged | New instance class |
| `--allocated-storage GB` | No | unchanged | New storage size |
| `--storage-type TYPE` | No | unchanged | Storage class |
| `--iops N` | No | unchanged | Provisioned IOPS |
| `--backup-retention-days N` | No | unchanged | Backup retention days |
| `--maintenance-window WINDOW` | No | unchanged | Preferred maintenance window |
| `--backup-window WINDOW` | No | unchanged | Preferred backup window |
| `--ca-certificate-id ID` | No | unchanged | CA certificate rotation target |
| `--multi-az` / `--no-multi-az` | No | unchanged | Multi-AZ toggle |
| `--auto-minor-version-upgrade` / `--no-auto-minor-version-upgrade` | No | unchanged | Minor upgrade policy |
| `--deletion-protection` / `--no-deletion-protection` | No | unchanged | Deletion protection policy |
| `--apply-immediately` | No | `false` | Apply now instead of maintenance window |
| `--wait` | No | `false` | Wait for `available` state |
| `--timeout SEC` | No | `7200` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION` | No | AWS config | Region override |
| `--profile PROFILE` | No | AWS config | Profile override |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: scale instance class and retention policy with maintenance-safe rollout.
- Common operational path: scheduled right-sizing or CA rotation during ops window.
- Failure path: no mutable flags provided or invalid window format.
- Recovery/rollback path: reapply previous known-good settings.

## Usage
```bash
cloud/aws/rds/modify-instance.sh \
  --identifier app-prod-db-01 \
  --instance-class db.r6g.large \
  --backup-retention-days 14 \
  --deletion-protection \
  --wait

cloud/aws/rds/modify-instance.sh \
  --identifier app-stg-db-01 \
  --allocated-storage 200 \
  --apply-immediately
```

## Behavior
- Main execution flow:
  - validates target instance exists
  - ensures at least one mutable change flag is provided
  - builds `modify-db-instance` request from provided flags
  - optionally applies immediately
  - optionally waits until status returns to `available`
- Idempotency notes: mostly idempotent when desired values already match current config.
- Side effects: may trigger reboot/failover depending on changed attributes.

## Output
- Standard output format:
  - stderr: timestamped logs
- Exit codes:
  - `0` success
  - `2` validation/precondition errors
  - non-zero on AWS/API/wait failures

## Failure Modes
- Common errors and likely causes:
  - invalid maintenance/backup window syntax
  - unsupported class/storage transition
  - IAM deny on modify action
- Recovery and rollback steps:
  - correct input and rerun
  - roll back to prior class/storage values
  - schedule changes in maintenance window when needed

## Security Notes
- Secret handling: no secret inputs required.
- Least-privilege requirements: scope modify permissions to approved DB resources.
- Audit/logging expectations: changes should be tied to approved operational tickets.

## Testing
- Unit tests:
  - no-op guard and flag validation
  - window format validation
- Integration tests:
  - non-production class/retention updates
- Manual verification:
  - validate post-change status, settings, and event stream in RDS
