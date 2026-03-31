# doc.sh

## Purpose
Generate quick-reference documentation for the shared timeout module.

## Location
`shared/timeout/doc.sh`

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
shared/timeout/doc.sh
shared/timeout/doc.sh --format text --output /tmp/timeout-doc.txt
```

## Output
- Exit codes: `0` success, `2` invalid args.
