# dashboard-sync.sh

## Purpose
Sync dashboard files for `datadog` monitoring workflows.

## Location
`monitoring/datadog/dashboard-sync.sh`

## Preconditions
- Required tools: `bash`, `cp`
- Required permissions: filesystem read/write based on provided paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--source PATH` | Yes | none | Source file or directory |
| `--destination PATH` | Yes | none | Destination directory |
| `--folder NAME` | No | `default` | Dashboard folder label |
| `--dry-run` | No | `false` | Print sync plan only |

## Usage
```bash
monitoring/datadog/dashboard-sync.sh --source ./dashboards --destination /tmp/datadog-dashboards --folder platform --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
