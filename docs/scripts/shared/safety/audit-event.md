# audit-event.sh

## Purpose
Emit structured JSON audit events for operational actions, outcomes, and metadata.

## Location
`shared/safety/audit-event.sh`

## Preconditions
- Required tools: `bash`, `date`
- Required permissions: write permissions for `--output` target file (if used)
- Required environment variables: optional `AUDIT_ACTOR`

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--action TEXT` | Yes | N/A | Action identifier |
| `--actor TEXT` | No | `AUDIT_ACTOR` or `USER` | Acting principal |
| `--target TEXT` | No | empty | Target resource id |
| `--status VALUE` | No | `info` | `info\|success\|failure\|warning` |
| `--message TEXT` | No | empty | Human-readable message |
| `--event-id ID` | No | generated id | Event correlation id |
| `--source TEXT` | No | script basename | Originating component |
| `--meta KEY=VALUE` | No | none | Metadata pair (repeatable, last key wins) |
| `--timestamp-format F` | No | `%Y-%m-%dT%H:%M:%S%z` | Timestamp format |
| `--output FILE` | No | stdout | Append event to file |
| `--pretty` | No | `false` | Multi-line JSON output |

## Scenarios
- Happy path: emit audit JSON to stdout for stream ingestion.
- Common operational path: append JSON lines to audit file.
- Failure path: missing action, invalid status, or invalid meta key.
- Recovery/rollback path: correct schema fields and rerun emit step.

## Usage
```bash
shared/safety/audit-event.sh --action deploy.start --status info --target service/api
shared/safety/audit-event.sh --action deploy.finish --status success --meta version=1.4.2 --meta env=prod
shared/safety/audit-event.sh --action db.backup --status failure --message "snapshot timeout" --output /var/log/devops-audit.log
```

## Behavior
- Main execution flow:
  - validate required fields and enums
  - generate timestamp/event id when absent
  - build escaped JSON payload
  - emit to stdout or append to output file
- Idempotency notes: each execution emits a new event (non-idempotent by design).
- Side effects: appends to audit file when `--output` is used.

## Output
- Standard output format: JSON object (compact by default, pretty with `--pretty`).
- Exit codes:
  - `0` event emitted successfully
  - `2` validation/usage error

## Failure Modes
- Common errors and likely causes:
  - missing `--action`
  - invalid `--status`
  - malformed `--meta` pair or invalid metadata key
  - output directory does not exist
- Recovery and rollback steps:
  - correct required fields and enums
  - ensure output path parent exists and is writable
  - validate metadata format before emission

## Security Notes
- Secret handling: avoid including credentials/tokens in message or metadata.
- Least-privilege requirements: restrict write access to audit output path.
- Audit/logging expectations: designed for SIEM/log pipeline ingestion.

## Testing
- Unit tests:
  - status enum and metadata validation
  - JSON escaping logic
- Integration tests:
  - append behavior to output files
- Manual verification:
  - emit success/failure events and validate JSON schema
