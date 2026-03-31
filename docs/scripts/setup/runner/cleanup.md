# cleanup.sh

## Purpose
Clean runner workspace and artifacts, with optional Docker cache pruning.

## Location
`setup/runner/cleanup.sh`

## Preconditions
- Required tools: `bash`, `find`, `rm`
- Required permissions: write access to workspace/artifacts paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--workspace DIR` | No | `~/work` | Runner workspace path |
| `--artifacts-dir DIR` | No | `~/work/artifacts` | Artifacts path |
| `--docker-prune` | No | `false` | Prune Docker cache if available |
| `--dry-run` | No | `false` | Print actions only |

## Scenarios
- Happy path: reset runner between jobs.
- Common path: prune artifacts nightly.
- Failure path: permission denied while deleting files.
- Recovery: fix ownership and rerun cleanup.

## Usage
```bash
setup/runner/cleanup.sh
setup/runner/cleanup.sh --docker-prune --dry-run
```

## Behavior
- Main flow: remove child items from workspace and artifacts dirs.
- Optional behavior: execute `docker system prune -f`.
- Side effects: deletes files.

## Output
- Dry-run traces on stderr when enabled.
- Exit codes: `0` success, `2` invalid arguments.

## Failure Modes
- Permission errors on cleanup targets.
- Docker daemon unavailable when prune requested.

## Security Notes
- Does not inspect secret values; only removes files.
- Use least privilege needed for cleanup paths.

## Testing
- Test on temp workspace with sample files.
- Validate `--dry-run` output before real cleanup.
