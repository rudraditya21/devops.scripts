# create-instance.sh

## Purpose
Create an AWS RDS DB instance with validated inputs, safer defaults, and optional readiness wait.

## Location
`cloud/aws/rds/create-instance.sh`

## Preconditions
- Required tools: `bash`, `aws`, `awk`, `date`, `sleep`
- Required permissions: `rds:CreateDBInstance`, `rds:DescribeDBInstances`, and related permissions for subnet/parameter/option groups if used
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--identifier ID` | Yes | N/A | Target DB instance identifier |
| `--engine ENGINE` | Yes | N/A | Database engine (non-Aurora) |
| `--instance-class CLASS` | Yes | N/A | DB instance class, for example `db.t3.medium` |
| `--allocated-storage GB` | Yes | N/A | Storage allocation in GiB |
| `--engine-version VERSION` | No | provider default | Engine version override |
| `--db-name NAME` | No | empty | Initial DB name |
| `--master-username USER` | Conditional | empty | Required unless managed password mode is used |
| `--master-password PASS` | Conditional | empty | Required unless managed password mode is used |
| `--manage-master-user-password` | No | `false` | Use AWS-managed secret for DB master password |
| `--storage-type TYPE` | No | `gp3` | Storage class |
| `--backup-retention-days N` | No | `7` | Automated backup retention |
| `--port PORT` | No | engine default | DB port override |
| `--db-subnet-group NAME` | No | empty | Target DB subnet group |
| `--parameter-group NAME` | No | empty | DB parameter group |
| `--option-group NAME` | No | empty | DB option group |
| `--vpc-security-group-id SG` | No | none | Security group ID (repeatable) |
| `--vpc-security-group-ids CSV` | No | none | CSV of security group IDs |
| `--multi-az` / `--no-multi-az` | No | `--no-multi-az` | Multi-AZ behavior |
| `--publicly-accessible` / `--no-publicly-accessible` | No | `--no-publicly-accessible` | Public networking behavior |
| `--deletion-protection` / `--no-deletion-protection` | No | `--deletion-protection` | Deletion guard |
| `--tag KEY=VALUE` | No | none | Tag pair (repeatable) |
| `--tags CSV` | No | none | CSV tags |
| `--wait` | No | `false` | Wait for `available` state |
| `--timeout SEC` | No | `3600` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION` | No | AWS config | Region override |
| `--profile PROFILE` | No | AWS config | Profile override |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: create a new production DB instance with deletion protection and 7-day backup retention.
- Common operational path: environment provisioning in CI before app deploy.
- Failure path: invalid identifier/engine/class or existing instance name collision.
- Recovery/rollback path: delete failed instance and recreate with corrected parameters.

## Usage
```bash
cloud/aws/rds/create-instance.sh \
  --identifier app-prod-db-01 \
  --engine postgres \
  --instance-class db.t3.medium \
  --allocated-storage 100 \
  --master-username dbadmin \
  --master-password 'REDACTED' \
  --db-subnet-group app-prod-db-subnets \
  --vpc-security-group-ids sg-0123456789abcdef0,sg-0fedcba9876543210 \
  --wait

cloud/aws/rds/create-instance.sh \
  --identifier app-stg-db-01 \
  --engine mysql \
  --instance-class db.t4g.medium \
  --allocated-storage 50 \
  --master-username appadmin \
  --manage-master-user-password \
  --tag Environment=staging \
  --tag Owner=platform
```

## Behavior
- Main execution flow:
  - validates required inputs and guardrails (Aurora rejected)
  - ensures target instance does not already exist
  - builds `create-db-instance` call with optional network, tags, and controls
  - optionally waits until DB status is `available`
  - prints created DB identifier
- Idempotency notes: not idempotent by default; repeated successful runs require a unique identifier.
- Side effects: provisions a billable DB instance and related storage/backups.

## Output
- Standard output format:
  - stderr: timestamped operational logs
  - stdout: created `DBInstanceIdentifier`
- Exit codes:
  - `0` success
  - `2` validation/precondition errors
  - non-zero on AWS/API failures or wait timeout

## Failure Modes
- Common errors and likely causes:
  - `DBInstanceAlreadyExists`: identifier collision
  - validation error on class/storage/engine input
  - permission denial for `rds:CreateDBInstance`
- Recovery and rollback steps:
  - choose a new identifier and rerun
  - verify IAM policy and subnet/security group references
  - delete partially created non-production instances if needed

## Security Notes
- Secret handling: prefer `--manage-master-user-password` for reduced credential exposure.
- Least-privilege requirements: grant only create/describe permissions in scoped accounts/regions.
- Audit/logging expectations: creation should map to change record and tagging policy.

## Testing
- Unit tests:
  - identifier, storage, and mutual-exclusion validation
- Integration tests:
  - create + wait in sandbox account
- Manual verification:
  - check instance status, backup retention, and deletion protection in RDS console
