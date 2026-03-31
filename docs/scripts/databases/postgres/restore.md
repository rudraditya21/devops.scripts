# restore.sh

## Purpose
Restore PostgreSQL backups from plain SQL or custom archive files.

## Location
`databases/postgres/restore.sh`

## Preconditions
- Required tools: `bash`, `psql`, `pg_restore`
- Required permissions: connect/create/modify permissions on target database
- Required environment variables: optional `PGPASSWORD` for non-interactive auth

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--host HOST` | No | `localhost` | PostgreSQL host |
| `--port PORT` | No | `5432` | PostgreSQL port |
| `--user USER` | Yes | N/A | Database user |
| `--database NAME` | Yes | N/A | Target database |
| `--input-file PATH` | Yes | N/A | Backup input file |
| `--format FORMAT` | No | `auto` | `auto\|custom\|plain` |
| `--clean` | No | `false` | Drop objects before recreate |
| `--create` | No | `false` | Include create database statements |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: restore a custom backup into a staging database.
- Common operational path: replay plain SQL dump into a fresh DB.
- Failure path: wrong format selection or incompatible target DB state.
- Recovery/rollback path: correct format/permissions and retry restore.

## Usage
```bash
databases/postgres/restore.sh --user app --database appdb --input-file /tmp/appdb.dump
databases/postgres/restore.sh --user app --database appdb --input-file /tmp/appdb.sql --format plain
```

## Behavior
- Main execution flow:
  - validates required inputs and file existence
  - auto-detects format when requested
  - runs `psql` (plain) or `pg_restore` (custom)
- Idempotency notes: depends on dump content and flags.
- Side effects: mutates database schema/data.

## Output
- Standard output format: restore tool logs/errors.
- Exit codes:
  - `0` success
  - `2` validation errors
  - non-zero on restore failures

## Failure Modes
- Common errors and likely causes:
  - input file missing/corrupt
  - permissions insufficient for restore actions
  - conflicting existing objects without `--clean`
- Recovery and rollback steps:
  - validate file integrity and format
  - use `--clean` where appropriate
  - restore into isolated database for troubleshooting

## Security Notes
- Secret handling: avoid putting credentials in command history.
- Least-privilege requirements: restore user should only have needed DDL/DML rights.
- Audit/logging expectations: restoration events should be tied to incident/change records.

## Testing
- Unit tests:
  - format detection and flag handling
- Integration tests:
  - restore backup into disposable database
- Manual verification:
  - run post-restore row-count and health queries
