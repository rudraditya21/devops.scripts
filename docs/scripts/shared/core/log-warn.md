# log-warn.sh

## Purpose
Emit structured WARN-level log lines with timestamp and tag metadata.

## Location
`shared/core/log-warn.sh`

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
| `MESSAGE...` | Yes | N/A | Warning message payload |

## Scenarios
- Happy path: emit warning to stderr with default metadata.
- Common operational path: log warning to stdout in JSON-less shell pipelines.
- Failure path: missing message or bad `--stream` value returns exit `1`.
- Recovery/rollback path: correct invocation and rerun; script has no state changes.

## Usage
```bash
shared/core/log-warn.sh "disk usage above threshold"
shared/core/log-warn.sh --tag monitor --stream stdout "api latency elevated"
LOG_TAG=scheduler shared/core/log-warn.sh --timestamp-format "%F %T" "retrying task"
```

## Behavior
- Main execution flow: parse arguments, require message, format timestamp, print warn line.
- Idempotency notes: idempotent; emits text only.
- Side effects: writes one line to selected stream.

## Output
- Standard output format: `<timestamp> [WARN] [<tag>] <message>`
- Exit codes:
  - `0` success
  - `1` invalid options or timestamp formatting failure

## Failure Modes
- Common errors and likely causes:
  - `MESSAGE is required`: no message text.
  - `invalid stream`: unsupported stream value.
  - timestamp format rejected by local `date` implementation.
- Recovery and rollback steps:
  - pass message tokens
  - switch to valid stream choice
  - adjust format string to platform-compatible values

## Security Notes
- Secret handling: warnings should not include credentials or private tokens.
- Least-privilege requirements: none beyond shell execution.
- Audit/logging expectations: can be consumed by stderr aggregators.

## Testing
- Unit tests:
  - options parse correctly
  - default stream is stderr
- Integration tests:
  - output redirection in shell pipelines
- Manual verification:
  - run sample commands and validate exit codes
