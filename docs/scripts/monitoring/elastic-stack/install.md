# install.sh

## Purpose
Install component metadata for `elastic-stack` monitoring workflows.

## Location
`monitoring/elastic-stack/install.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: filesystem read/write based on provided paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--version VALUE` | No | `latest` | Version label |
| `--channel NAME` | No | `stable` | Release channel |
| `--install-dir PATH` | No | `/opt/elastic-stack` | Install directory |
| `--config-dir PATH` | No | `/etc/elastic-stack` | Config directory |
| `--bin-dir PATH` | No | `/usr/local/bin` | Binary directory |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
monitoring/elastic-stack/install.sh --version v1.2.3 --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
