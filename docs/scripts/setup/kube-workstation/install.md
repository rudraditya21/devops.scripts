# install.sh

## Purpose
Install baseline Kubernetes workstation tools (`kubectl`, `helm`).

## Location
`setup/kube-workstation/install.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: package manager permissions on host
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--manager NAME` | No | `auto` | Package manager override |
| `--yes` | No | `false` | Non-interactive install |
| `--dry-run` | No | `false` | Print commands only |
| `--update-cache` | No | `false` | Refresh package metadata |

## Scenarios
- Provision a new Kubernetes operator workstation.

## Usage
```bash
setup/kube-workstation/install.sh
setup/kube-workstation/install.sh --manager brew --dry-run
```

## Behavior
- Delegates installation to `setup/local/install-cli-tools.sh` with Kubernetes tool set.

## Output
- Installer output from delegated script.

## Failure Modes
- Missing installer script or package manager issues.

## Security Notes
- Uses existing package manager trust chain.

## Testing
- Run dry-run to verify planned package commands.
