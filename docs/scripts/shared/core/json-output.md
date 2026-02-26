# json-output.sh

## Purpose
Build a JSON object from `KEY=VALUE` pairs without external JSON tooling dependencies.

## Location
`shared/core/json-output.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on script file
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--pretty` | No | `false` | Render multi-line formatted JSON |
| `--infer-types` | No | `false` | Convert booleans/null/numbers to JSON scalars |
| `--from-stdin` | No | `false` | Read `KEY=VALUE` pairs from stdin |
| `KEY=VALUE [KEY=VALUE...]` | Conditional | N/A | Inline pairs (required unless stdin provides pairs) |

## Scenarios
- Happy path: convert inline pairs to compact JSON.
- Common operational path: ingest pairs from stdin in pipelines.
- Failure path: invalid key format or malformed pair returns exit `2`.
- Recovery/rollback path: correct input pair syntax and rerun.

## Usage
```bash
shared/core/json-output.sh service=api env=prod replicas=3
shared/core/json-output.sh --infer-types enabled=true retries=5 timeout=1.5
printf '%s\n' 'region=us-east-1' 'team=platform' | shared/core/json-output.sh --from-stdin --pretty
```

## Behavior
- Main execution flow: parse options, collect pairs from args/stdin, validate keys, emit JSON object.
- Idempotency notes: deterministic for same inputs.
- Side effects: none beyond stdout.

## Output
- Standard output format:
  - compact JSON object by default
  - pretty multi-line object with `--pretty`
- Exit codes:
  - `0` success
  - `2` invalid options or malformed key/value input

## Failure Modes
- Common errors and likely causes:
  - `no key=value pairs provided`
  - `invalid pair (expected KEY=VALUE)`
  - `invalid key`
- Recovery and rollback steps:
  - ensure each pair includes `=`
  - use valid key pattern (`[A-Za-z_][A-Za-z0-9_.-]*`)
  - confirm stdin source emits one pair per line

## Security Notes
- Secret handling: script may output secret values if provided; avoid logging raw output for sensitive contexts.
- Least-privilege requirements: no elevated permissions.
- Audit/logging expectations: suitable for constructing controlled JSON payloads in automation.

## Testing
- Unit tests:
  - key validation
  - type inference behavior
  - stdin + arg merge behavior
- Integration tests:
  - pipe output into API clients or downstream scripts
- Manual verification:
  - run examples and validate JSON formatting/typing
