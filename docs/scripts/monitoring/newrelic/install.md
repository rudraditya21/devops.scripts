# install.sh

## Purpose
Install component metadata for `newrelic` monitoring workflows.

## Location
`monitoring/newrelic/install.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: filesystem read/write based on provided paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--version VALUE` | No | `latest` | Version label |
| `--channel NAME` | No | `stable` | Release channel |
| `--install-dir PATH` | No | `/opt/newrelic` | Install directory |
| `--config-dir PATH` | No | `/etc/newrelic` | Config directory |
| `--bin-dir PATH` | No | `/usr/local/bin` | Binary directory |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
monitoring/newrelic/install.sh --version v1.2.3 --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
