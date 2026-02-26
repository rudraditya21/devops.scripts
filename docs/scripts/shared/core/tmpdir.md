# tmpdir.sh

## Purpose
Create secure temporary directories for script execution and optionally manage lifecycle around a child command.

## Location
`shared/core/tmpdir.sh`

## Preconditions
- Required tools: `bash`, `mktemp`, `chmod`, `rm`
- Required permissions: write permission to base temp directory
- Required environment variables: none (`TMPDIR` is optional)

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--prefix PREFIX` | No | `devops` | Temporary directory prefix |
| `--base-dir DIR` | No | `$TMPDIR` or `/tmp` | Parent directory for temp path |
| `--mode OCTAL` | No | `700` | Permission mode applied after creation |
| `--env-var NAME` | No | `DEVOPS_TMPDIR` | Exported variable name when running command |
| `--keep` | No | `false` | Preserve directory after command execution |
| `-- COMMAND...` | No | none | Command to run with temp dir exported |

## Scenarios
- Happy path: create temp directory and print path.
- Common operational path: run command with temp dir auto-cleanup.
- Failure path: invalid base directory/mode causes exit `2`.
- Recovery/rollback path: fix path permissions or options; rerun.

## Usage
```bash
shared/core/tmpdir.sh --prefix release
shared/core/tmpdir.sh --prefix build -- /bin/sh -c 'echo "$DEVOPS_TMPDIR"; ls -la "$DEVOPS_TMPDIR"'
shared/core/tmpdir.sh --keep --env-var WORK_TMP -- /bin/sh -c 'echo "$WORK_TMP"'
```

## Behavior
- Main execution flow:
  - validate base directory and options
  - create directory via `mktemp -d`
  - optionally run child command with exported temp-dir env var
  - cleanup unless `--keep`
- Idempotency notes: non-idempotent path creation by design.
- Side effects: filesystem directory create/remove operations.

## Output
- Standard output format:
  - no command: temp directory path to stdout
  - with command: child command output
- Exit codes:
  - `0` success
  - child command exit code when command fails
  - `2` invalid invocation/input
  - `70` cleanup failure after successful command

## Failure Modes
- Common errors and likely causes:
  - base directory does not exist or is not writable
  - invalid `--mode` or `--env-var` value
  - `mktemp` failure due to environment restrictions
- Recovery and rollback steps:
  - choose writable base directory
  - fix invalid mode/env-var syntax
  - if `--keep` was used, remove stale temp dir manually when done

## Security Notes
- Secret handling: temp directory may hold sensitive artifacts; default mode `700` minimizes exposure.
- Least-privilege requirements: avoid running as root unless required by child command.
- Audit/logging expectations: log temp path only if not sensitive.

## Testing
- Unit tests:
  - option validation (`--mode`, `--env-var`)
  - keep/cleanup branching
- Integration tests:
  - verify environment variable export to child command
- Manual verification:
  - inspect permissions and cleanup behavior with and without `--keep`
