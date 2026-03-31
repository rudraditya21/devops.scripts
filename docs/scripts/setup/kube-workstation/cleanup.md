# cleanup.sh

## Purpose
Clean Kubernetes and Helm local cache directories.

## Location
`setup/kube-workstation/cleanup.sh`

## Preconditions
- Required tools: `bash`, `rm`
- Required permissions: write access to cache paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--kube-cache-dir DIR` | No | `~/.kube/cache` | Kube cache dir |
| `--helm-cache-dir DIR` | No | `~/.cache/helm` | Helm cache dir |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
setup/kube-workstation/cleanup.sh --dry-run
```

## Behavior
- Removes configured cache directories if present.

## Output
- Dry-run action traces when enabled.

## Failure Modes
- Permission denied on cache paths.

## Security Notes
- Operates on local cache files only.

## Testing
- Run against temporary cache directories.
