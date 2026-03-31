# backup.sh

## Purpose
Create MySQL backups using `mysqldump` with optional transactional consistency mode.

## Location
`databases/mysql/backup.sh`

## Preconditions
- Required tools: `bash`, `mysqldump`
- Required permissions: MySQL read privileges on target database
- Required environment variables: optional `MYSQL_PWD` for non-interactive auth

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--host HOST` | No | `localhost` | MySQL host |
| `--port PORT` | No | `3306` | MySQL port |
| `--user USER` | Yes | N/A | Database user |
| `--database NAME` | Yes | N/A | Database to back up |
| `--output-file PATH` | Yes | N/A | SQL output file |
| `--single-transaction` | No | `true` | Consistent snapshot mode |
| `--no-single-transaction` | No | `false` | Disable snapshot mode |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: export production-like schema/data in transactional mode.
- Common operational path: backup before migration or bulk updates.
- Failure path: missing dump privileges or output write access issues.
- Recovery/rollback path: fix auth/path and rerun backup.

## Usage
```bash
databases/mysql/backup.sh --user app --database appdb --output-file /tmp/appdb.sql
databases/mysql/backup.sh --user app --database appdb --output-file /tmp/appdb.sql --no-single-transaction
```

## Behavior
- Main execution flow:
  - validates required parameters
  - builds mysqldump command with optional transaction flag
  - writes SQL dump to output file
- Idempotency notes: repeatable but overwrites output file.
- Side effects: file write to backup destination.

## Output
- Standard output format: mysqldump logs/errors.
- Exit codes:
  - `0` success
  - `2` validation errors
  - non-zero on dump/auth/runtime failures

## Failure Modes
- Common errors and likely causes:
  - access denied for dump user
  - target file path not writable
  - connectivity issues to MySQL host
- Recovery and rollback steps:
  - verify user privileges
  - check filesystem permissions
  - test connectivity with mysql client

## Security Notes
- Secret handling: pass credentials via secure env methods.
- Least-privilege requirements: read access only for backup user.
- Audit/logging expectations: backup invocation should be traceable in ops logs.

## Testing
- Unit tests:
  - argument and flag validation
- Integration tests:
  - backup test database with both transaction modes
- Manual verification:
  - inspect output SQL and test import into sandbox
