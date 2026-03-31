# doc.sh

## Purpose
Generate quick-reference documentation for the shared logging module.

## Location
`shared/logging/doc.sh`

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
shared/logging/doc.sh
shared/logging/doc.sh --format text --output /tmp/logging-doc.txt
```

## Behavior
- Renders module script/dependency summary.
- Emits to stdout or writes to file.

## Output
- Exit codes: `0` success, `2` invalid args.
