# backup.sh

## Purpose
Create PostgreSQL backups using `pg_dump` with custom or plain formats.

## Location
`databases/postgres/backup.sh`

## Preconditions
- Required tools: `bash`, `pg_dump`
- Required permissions: PostgreSQL connect and read privileges for target database
- Required environment variables: optional `PGPASSWORD` for non-interactive auth

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--host HOST` | No | `localhost` | PostgreSQL host |
| `--port PORT` | No | `5432` | PostgreSQL port |
| `--user USER` | Yes | N/A | Database user |
| `--database NAME` | Yes | N/A | Database to back up |
| `--output-file PATH` | Yes | N/A | Backup file path |
| `--format FORMAT` | No | `custom` | `custom\|plain` |
| `--compress-level N` | No | `6` | Compression level for custom format |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: create compressed custom archive for routine backups.
- Common operational path: export plain SQL for migration handoff.
- Failure path: missing privileges or invalid output path.
- Recovery/rollback path: fix auth/path and rerun backup.

## Usage
```bash
databases/postgres/backup.sh --user app --database appdb --output-file /tmp/appdb.dump
databases/postgres/backup.sh --user app --database appdb --output-file /tmp/appdb.sql --format plain
```

## Behavior
- Main execution flow:
  - validates required parameters
  - builds `pg_dump` command according to selected format
  - executes or prints in dry-run mode
- Idempotency notes: repeatable; creates/overwrites backup file.
- Side effects: writes backup artifact.

## Output
- Standard output format: pg_dump output/logs.
- Exit codes:
  - `0` success
  - `2` argument/prerequisite errors
  - non-zero on dump/auth/runtime errors

## Failure Modes
- Common errors and likely causes:
  - auth failure for supplied user
  - inaccessible host/port
  - write permission denied on output path
- Recovery and rollback steps:
  - verify credentials and network access
  - ensure destination directory is writable
  - rerun with corrected arguments

## Security Notes
- Secret handling: passwords should come from env/secure auth methods, not flags.
- Least-privilege requirements: read access only for target database.
- Audit/logging expectations: backup runs should be tracked by schedule/ticket.

## Testing
- Unit tests:
  - format/argument validation
- Integration tests:
  - backup non-production database in both formats
- Manual verification:
  - inspect backup file and run a test restore
