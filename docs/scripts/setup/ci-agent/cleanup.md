# cleanup.sh

## Purpose
Clean CI agent workspace and artifact directories between runs.

## Location
`setup/ci-agent/cleanup.sh`

## Preconditions
- Required tools: `bash`, `find`, `rm`
- Required permissions: write access to cleanup targets
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--workspace DIR` | No | `~/work/ci-agent` | Workspace path |
| `--artifacts-dir DIR` | No | `~/work/ci-agent/artifacts` | Artifacts path |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Clean agent state before/after pipeline runs.
- Remove stale artifacts safely with dry-run preview.

## Usage
```bash
setup/ci-agent/cleanup.sh --dry-run
setup/ci-agent/cleanup.sh
```

## Behavior
- Removes child items from workspace and artifact directories.
- Leaves root directories intact.

## Output
- Dry-run command traces to stderr.
- Exit codes: `0` success, `2` invalid arguments.

## Failure Modes
- Permission denied on target directories.

## Security Notes
- Operates on paths only; does not process secret values.

## Testing
- Validate cleanup in temporary directories.
