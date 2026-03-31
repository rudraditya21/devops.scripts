# verify.sh

## Purpose
Verify local DB toolchain (`psql`, `pg_dump`, `mysql`, `mysqldump`) and config file presence.

## Location
`setup/db-tools/verify.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: read access to user config files
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--strict` | No | `false` | Treat WARN as failure |
| `--json` | No | `false` | Emit JSON report |

## Usage
```bash
setup/db-tools/verify.sh
setup/db-tools/verify.sh --strict --json
```

## Behavior
- Checks DB client command availability.
- Checks presence of `~/.pgpass` and `~/.my.cnf`.

## Output
- Table or JSON PASS/WARN/FAIL summary.

## Failure Modes
- Missing command-line tools.
- Missing DB client config files.

## Security Notes
- Reports presence only, not credential contents.

## Testing
- Run in environments with partial/missing DB tools.
