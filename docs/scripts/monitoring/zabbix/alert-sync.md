# alert-sync.sh

## Purpose
Sync alert rule files for `zabbix` monitoring workflows.

## Location
`monitoring/zabbix/alert-sync.sh`

## Preconditions
- Required tools: `bash`, `cp`
- Required permissions: filesystem read/write based on provided paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--source PATH` | Yes | none | Source file or directory |
| `--destination PATH` | Yes | none | Destination directory |
| `--strategy replace\|merge` | No | `merge` | Sync strategy |
| `--dry-run` | No | `false` | Print sync plan only |

## Usage
```bash
monitoring/zabbix/alert-sync.sh --source ./alerts --destination /tmp/zabbix-alerts --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
