# parse-args.sh

## Purpose
Normalize CLI-style arguments into structured JSON or key-value output for downstream shell automation.

## Location
`shared/core/parse-args.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on script file
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--output json\|kv` | No | `json` | Output format |
| `--` | Yes (recommended) | N/A | Separator before arguments to parse |
| `ARGUMENTS...` | Yes | N/A | Target tokens to parse |

## Scenarios
- Happy path: parse long flags and positionals into JSON.
- Common operational path: emit `kv` format for pure-shell consumption.
- Failure path: unsupported syntax or invalid option names produce exit `2`.
- Recovery/rollback path: correct invocation format and rerun parser.

## Usage
```bash
shared/core/parse-args.sh -- --name alice --no-color -abc deploy
shared/core/parse-args.sh --output kv -- --region us-east-1 -v -x=42 task
shared/core/parse-args.sh -- --token=abc123 --retry 3 -- payload
```

## Behavior
- Main execution flow:
  - parse parser-level flags (`--output`)
  - scan target tokens and classify options/positionals
  - preserve repeated options (arrays in JSON)
- Idempotency notes: pure transformation; no side effects.
- Side effects: none beyond deterministic output.

## Output
- Standard output format:
  - `json`: `{"options":{...},"positionals":[...]}`
  - `kv`: `opt.key=value`, `positional[n]=value`
- Exit codes:
  - `0` parse success
  - `2` usage error or unsupported option syntax

## Failure Modes
- Common errors and likely causes:
  - `ARGUMENTS are required` when parse target tokens are missing
  - `unsupported option syntax` for forms not implemented
  - invalid long/short key format
- Recovery and rollback steps:
  - use supported forms (`--flag`, `--key=value`, `-abc`, etc.)
  - pass parse target args after `--`

## Security Notes
- Secret handling: parser echoes argument values; avoid passing raw secrets when logs are captured.
- Least-privilege requirements: no elevated permissions required.
- Audit/logging expectations: useful for deterministic CLI normalization in wrappers.

## Testing
- Unit tests:
  - every supported token form
  - repeated option behavior
  - invalid syntax rejection
- Integration tests:
  - consume JSON output in subsequent shell scripts
- Manual verification:
  - run examples and compare output shape with expected structure
