# healthcheck.sh

## Purpose
Validate MySQL service reachability and optional query execution readiness.

## Location
`databases/mysql/healthcheck.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: DB login rights for supplied user
- Required environment variables: optional `MYSQL_PWD` for auth

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--host HOST` | No | `localhost` | MySQL host |
| `--port PORT` | No | `3306` | MySQL port |
| `--user USER` | Yes | N/A | Database user |
| `--database NAME` | No | none | Optional DB for query check |
| `--strict` | No | `false` | WARN treated as failure |
| `--json` | No | `false` | JSON report output |

## Scenarios
- Happy path: ping and optional query checks pass.
- Common operational path: run in deployment health gates.
- Failure path: MySQL unreachable or auth failure.
- Recovery/rollback path: fix connectivity/credentials and rerun.

## Usage
```bash
databases/mysql/healthcheck.sh --user app --json
databases/mysql/healthcheck.sh --user app --database appdb --strict
```

## Behavior
- Main execution flow:
  - validates input user
  - checks availability of `mysqladmin` and `mysql`
  - runs ping check and optional `SELECT 1` query
  - emits PASS/WARN/FAIL summary
- Idempotency notes: read-only checks.
- Side effects: none.

## Output
- Standard output format: table summary (default) or JSON.
- Exit codes:
  - `0` healthy (and no warnings in strict mode)
  - `1` failures detected (or warnings in strict mode)
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - missing client tools
  - host/port unreachable
  - insufficient DB privileges
- Recovery and rollback steps:
  - install required tools
  - verify network access and authentication
  - confirm user privileges for query checks

## Security Notes
- Secret handling: credentials should be sourced from secure env management.
- Least-privilege requirements: read-only permissions for health checks.
- Audit/logging expectations: healthcheck runs should be included in operational evidence.

## Testing
- Unit tests:
  - strict/json and argument validation
- Integration tests:
  - run against healthy/unhealthy test endpoints
- Manual verification:
  - compare output with direct mysqladmin/mysql commands
