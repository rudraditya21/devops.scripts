# Script Documentation Spec

Use this structure for every script page.

## Template

````markdown
# <script-name>

## Purpose

One clear statement of what the script does.

## Location

`<relative/path/to/script.sh>`

## Preconditions

- Required tools:
- Required permissions:
- Required environment variables:

## Arguments

| Flag | Required | Default | Description |
| ---- | -------- | ------- | ----------- |
|      |          |         |             |

## Scenarios

- Happy path:
- Common operational path:
- Failure path:
- Recovery/rollback path:

## Usage

```bash
<command example 1>
<command example 2>
```

## Behavior

- Main execution flow:
- Idempotency notes:
- Side effects:

## Output

- Standard output format:
- Exit codes:
  - `0` success
  - non-zero failure cases

## Failure Modes

- Common errors and likely causes
- Recovery and rollback steps

## Security Notes

- Secret handling
- Least-privilege requirements
- Audit/logging expectations

## Testing

- Unit tests:
- Integration tests:
- Manual verification:
````

## Acceptance Criteria

A script doc is complete only when:

- all sections above are filled with operationally useful details
- scenarios are explicit and actionable
- examples are copy-paste ready
- failure and recovery guidance is specific enough for on-call usage
