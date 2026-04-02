# configure.sh

## Purpose
Generate service configuration for `newrelic` monitoring workflows.

## Location
`monitoring/newrelic/configure.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: filesystem read/write based on provided paths
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--config-file PATH` | Yes | none | Output config path |
| `--endpoint URL` | No | `http://localhost` | Service endpoint |
| `--namespace NAME` | No | `default` | Namespace label |
| `--retention VALUE` | No | `30d` | Data retention window |
| `--scrape-interval S` | No | `30s` | Collection interval |
| `--dry-run` | No | `false` | Print config only |

## Usage
```bash
monitoring/newrelic/configure.sh --config-file /tmp/newrelic.yml --endpoint http://monitoring.internal --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
