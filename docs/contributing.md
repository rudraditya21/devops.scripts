# Contributing

Follow this workflow for every new script.

## 1. Choose Correct Domain

Place scripts in the right top-level folder (`cloud/`, `databases/`, `security/`, etc.) and subfolder by provider/service when needed.

## 2. Implement Script

Minimum implementation baseline:

- Strict mode (`set -euo pipefail`)
- Input validation
- Help text with usage examples
- Logging and explicit exit behavior
- Dry-run mode for mutating actions

## 3. Add Tests

- Add tests covering success and failure paths.
- Validate idempotency and safety controls.
- Ensure tests can run in CI without hidden local dependencies.

## 4. Add Documentation

Create/update doc pages in `docs/` using the script documentation spec.

## 5. Validate Before PR

```bash
mkdocs build --strict
```

Run script tests and lint checks before opening a PR.

## 6. Pull Request Checklist

- Script and tests included
- Documentation included
- Security and safety checks included
- Usage examples verified
- Reviewer notes added for operational risk
