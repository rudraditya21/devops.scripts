# example.sh

## Purpose
Demonstrate command and environment validation using shared core validators.

## Location
`shared/validation/example.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on dependency scripts
- Required environment variables: depends on `--require-envs`

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--require-cmds LIST` | No | `bash,awk` | Comma-separated command list |
| `--require-envs LIST` | No | `HOME,PATH` | Comma-separated env var list |
| `--allow-empty VAR` | No | none | Allow empty value for a variable |
| `--json` | No | `false` | Forward JSON output mode |

## Usage
```bash
shared/validation/example.sh
shared/validation/example.sh --require-cmds bash,jq --require-envs HOME,CI --json
```

## Behavior
- Calls `shared/core/require-cmd.sh` and `shared/core/require-env.sh` with parsed lists.

## Output
- Exit codes: `0` success, `1` validation failure, `2` invalid args/dependency errors.
