# doc.sh

## Purpose
Generate quick-reference documentation for the shared lock module.

## Location
`shared/lock/doc.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: write permission when using `--output`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--format FORMAT` | No | `markdown` | Output format: `markdown` or `text` |
| `--output PATH` | No | stdout | Write rendered content to file |

## Usage
```bash
shared/lock/doc.sh
shared/lock/doc.sh --format text --output /tmp/lock-doc.txt
```

## Output
- Exit codes: `0` success, `2` invalid args.
