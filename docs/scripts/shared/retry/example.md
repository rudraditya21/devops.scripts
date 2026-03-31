# example.sh

## Purpose
Provide a convenience wrapper demonstrating retry policy options.

## Location
`shared/retry/example.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on `shared/safety/retry.sh`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--attempts N` | No | `3` | Retry attempt count |
| `--delay SEC` | No | `1` | Initial delay |
| `--backoff FACTOR` | No | `2` | Delay multiplier |
| `--max-delay SEC` | No | `0` | Delay cap |
| `--jitter PERCENT` | No | `0` | Positive jitter percentage |
| `--retry-on CODES` | No | all non-zero | Comma-separated retriable status codes |
| `--quiet` | No | `false` | Suppress retry logs |
| `-- COMMAND ...` | No | built-in sample command | Command to run under retry |

## Usage
```bash
shared/retry/example.sh
shared/retry/example.sh --attempts 5 --delay 0.5 --retry-on 28 -- curl -fsS https://example.com/health
```

## Output
- Exit codes: same behavior as `shared/safety/retry.sh`.
