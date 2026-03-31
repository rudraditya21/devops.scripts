# healthcheck.sh

## Purpose
Validate PostgreSQL service reachability and optional query execution readiness.

## Location
`databases/postgres/healthcheck.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: DB login rights for supplied user
- Required environment variables: optional `PGPASSWORD` for auth

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--host HOST` | No | `localhost` | PostgreSQL host |
| `--port PORT` | No | `5432` | PostgreSQL port |
| `--user USER` | Yes | N/A | Database user |
| `--database NAME` | No | none | Optional DB for `SELECT 1` check |
| `--strict` | No | `false` | WARN treated as failure |
| `--json` | No | `false` | JSON report output |

## Scenarios
- Happy path: service is reachable and optional query succeeds.
- Common operational path: use in pre-deployment health gates.
- Failure path: DB unreachable or credentials invalid.
- Recovery/rollback path: fix network/auth and rerun check.

## Usage
```bash
databases/postgres/healthcheck.sh --user app --json
databases/postgres/healthcheck.sh --user app --database appdb --strict
```

## Behavior
- Main execution flow:
  - checks `pg_isready` and `psql` command availability
  - verifies endpoint readiness with `pg_isready`
  - optionally runs `SELECT 1` query against target database
  - emits PASS/WARN/FAIL summary
- Idempotency notes: read-only health probe.
- Side effects: none.

## Output
- Standard output format: table summary (default) or JSON.
- Exit codes:
  - `0` healthy (and no warnings in strict mode)
  - `1` failures detected (or warnings in strict mode)
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - missing PostgreSQL client tools
  - host/port unreachable
  - authentication failure
- Recovery and rollback steps:
  - install required client binaries
  - verify network/firewall
  - validate credentials and DB permissions

## Security Notes
- Secret handling: credentials should be sourced securely via environment or vault tooling.
- Least-privilege requirements: read-only connection permissions are sufficient.
- Audit/logging expectations: healthcheck outputs should be retained for incident timelines.

## Testing
- Unit tests:
  - strict/json behavior and argument parsing
- Integration tests:
  - run against healthy and intentionally failing instances
- Manual verification:
  - compare with direct `pg_isready` and `psql` checks
