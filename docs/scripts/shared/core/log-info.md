# log-info.sh

## Purpose
Emit structured INFO-level log lines with timestamp and tag metadata.

## Location
`shared/core/log-info.sh`

## Preconditions
- Required tools: `bash`, `date`
- Required permissions: execute permission on script file
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--tag TAG` | No | `LOG_TAG` or script basename | Log tag value in output |
| `--timestamp-format FORMAT` | No | `LOG_TIMESTAMP_FORMAT` or `%Y-%m-%dT%H:%M:%S%z` | `date` format string |
| `--stream stdout\|stderr` | No | `stderr` | Output stream target |
| `MESSAGE...` | Yes | N/A | Message payload |

## Scenarios
- Happy path: log one message to stderr with default timestamp and tag.
- Common operational path: force logs to stdout for pipeline-friendly collection.
- Failure path: missing message or invalid `--stream` triggers exit `1`.
- Recovery/rollback path: fix invocation flags and rerun; no persistent side effects.

## Usage
```bash
shared/core/log-info.sh "deployment started"
shared/core/log-info.sh --tag deploy --stream stdout "rollout complete"
LOG_TAG=worker shared/core/log-info.sh --timestamp-format "%Y-%m-%d %H:%M:%S" "heartbeat"
```

## Behavior
- Main execution flow: parse flags, validate message presence, format timestamp, print line.
- Idempotency notes: idempotent; produces output only.
- Side effects: writes one line to selected stream.

## Output
- Standard output format: `<timestamp> [INFO] [<tag>] <message>`
- Exit codes:
  - `0` success
  - `1` invalid arguments or timestamp formatting failure

## Failure Modes
- Common errors and likely causes:
  - `MESSAGE is required`: no message tokens were passed.
  - `invalid stream`: value other than `stdout` or `stderr`.
  - `failed to format timestamp`: invalid `date` format string for platform.
- Recovery and rollback steps:
  - provide a message
  - correct stream value
  - use platform-compatible `date` format

## Security Notes
- Secret handling: avoid logging sensitive values.
- Least-privilege requirements: no elevated permissions required.
- Audit/logging expectations: suitable for structured human-readable audit trails.

## Testing
- Unit tests:
  - argument parsing and error paths
  - stream routing behavior
- Integration tests:
  - verify log capture in stdout/stderr pipelines
- Manual verification:
  - run examples and confirm output format and exit code
