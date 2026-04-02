# query.sh

## Purpose
Run normalized metric/log/trace query for `elastic-stack` monitoring workflows.

## Location
`monitoring/elastic-stack/query.sh`

## Preconditions
- Required tools: `bash`, `awk`
- Required permissions: none
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--expr QUERY` | Yes | none | Query expression |
| `--from TIME` | No | `now-1h` | Start time label |
| `--to TIME` | No | `now` | End time label |
| `--step SECONDS` | No | `60` | Sampling step |
| `--endpoint URL` | No | `http://localhost` | Query endpoint |
| `--format table\|json` | No | `table` | Output format |

## Usage
```bash
monitoring/elastic-stack/query.sh --expr 'up{job="api"}' --format json
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
