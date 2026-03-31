# restore.sh

## Purpose
Restore MySQL database content from an SQL backup file.

## Location
`databases/mysql/restore.sh`

## Preconditions
- Required tools: `bash`, `mysql`
- Required permissions: target database write/DDL permissions
- Required environment variables: optional `MYSQL_PWD` for non-interactive auth

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--host HOST` | No | `localhost` | MySQL host |
| `--port PORT` | No | `3306` | MySQL port |
| `--user USER` | Yes | N/A | Database user |
| `--database NAME` | Yes | N/A | Target database |
| `--input-file PATH` | Yes | N/A | SQL input file |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: restore SQL dump into a staging database.
- Common operational path: database recovery from validated backup artifact.
- Failure path: invalid SQL file or insufficient database permissions.
- Recovery/rollback path: correct file/auth and rerun restore.

## Usage
```bash
databases/mysql/restore.sh --user app --database appdb --input-file /tmp/appdb.sql
```

## Behavior
- Main execution flow:
  - validates required inputs and file existence
  - runs `mysql` client with SQL redirected from input file
- Idempotency notes: depends on SQL content and existing DB state.
- Side effects: mutates target database schema/data.

## Output
- Standard output format: mysql client logs/errors.
- Exit codes:
  - `0` success
  - `2` validation errors
  - non-zero on restore/runtime failures

## Failure Modes
- Common errors and likely causes:
  - input file not found
  - SQL conflicts with existing objects
  - missing write privileges
- Recovery and rollback steps:
  - validate SQL file and target database
  - run restore in disposable environment first
  - adjust privileges and retry

## Security Notes
- Secret handling: avoid exposing passwords in shell history.
- Least-privilege requirements: minimal DDL/DML rights for restore operator.
- Audit/logging expectations: restore runs should map to incident/change context.

## Testing
- Unit tests:
  - argument and file validation
- Integration tests:
  - restore into non-production target
- Manual verification:
  - run post-restore integrity checks
