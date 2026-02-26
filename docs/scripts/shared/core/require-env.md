# require-env.sh

## Purpose
Validate that required environment variables are set (and non-empty by default) before running dependent logic.

## Location
`shared/core/require-env.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: execute permission on script file
- Required environment variables: target variables being validated

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--allow-empty VAR` | No | none | Mark specific variable as valid even if empty |
| `--quiet` | No | `false` | Suppress success message in non-JSON mode |
| `--json` | No | `false` | Emit machine-readable JSON report |
| `VAR [VAR...]` | Yes | N/A | Environment variable names to validate |

## Scenarios
- Happy path: all required variables are set with non-empty values.
- Common operational path: allow empty placeholders for specific variables.
- Failure path: missing variable or empty disallowed variable yields exit `1`.
- Recovery/rollback path: export required variables and rerun preflight.

## Usage
```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=prod
shared/core/require-env.sh AWS_REGION AWS_PROFILE

export OPTIONAL_TAG=""
shared/core/require-env.sh --allow-empty OPTIONAL_TAG OPTIONAL_TAG

shared/core/require-env.sh --json DB_HOST DB_USER DB_PASSWORD
```

## Behavior
- Main execution flow: parse options, validate variable names, classify `present`, `missing`, and `empty`.
- Idempotency notes: idempotent and read-only.
- Side effects: none beyond output and exit status.

## Output
- Standard output format:
  - text mode: summary or missing/empty errors
  - JSON mode: `{"required":[],"present":[],"missing":[],"empty":[]}`
- Exit codes:
  - `0` all variables valid
  - `1` missing or disallowed empty variables
  - `2` usage/invalid variable name

## Failure Modes
- Common errors and likely causes:
  - invalid variable identifier format
  - variable referenced but not exported
  - empty value passed without `--allow-empty`
- Recovery and rollback steps:
  - export required variables
  - add intentional empty vars to `--allow-empty`
  - correct invalid variable names

## Security Notes
- Secret handling: validates presence only; does not print values.
- Least-privilege requirements: no elevated permissions required.
- Audit/logging expectations: safe for preflight checks in CI logs.

## Testing
- Unit tests:
  - variable-name validation
  - `--allow-empty` behavior
- Integration tests:
  - run against controlled environment variable sets
- Manual verification:
  - test one missing, one empty, and all-valid cases
