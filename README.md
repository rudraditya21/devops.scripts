# DevOps Scripts Library

Industry-grade DevOps automation scripts with strict standards for safety, reliability, and documentation.

## Purpose

- Provide reusable scripts for real production operations.
- Standardize quality across cloud, platform, CI/CD, database, security, and SRE workflows.
- Keep every script auditable, testable, and documented.

## Repository Structure

```text
devops.scripts/
├── cloud/
├── containers/
├── infrastructure/
├── cicd/
├── databases/
├── monitoring/
├── security/
├── networking/
├── backup/
├── cost/
├── git/
├── sre/
├── setup/
├── shared/
└── docs/
```

## Engineering Standards

Every production script must include:

- `set -euo pipefail`
- explicit input and environment validation
- deterministic behavior and clear exit codes
- structured logging and actionable error messages
- `--dry-run` for mutating operations
- usage/help output with examples
- tests for success and failure paths
- matching documentation in `docs/`

## Tooling Setup

Install required quality tools.

macOS:

```bash
brew install shfmt shellcheck
```

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y shfmt shellcheck
```

Install docs environment:

```bash
make docs-install
```

## Developer Commands

```bash
make format        # Format all bash scripts
make format-check  # Check formatting only
make lint          # Lint bash scripts (shellcheck)
make docs-build    # Build docs in strict mode
make docs-serve    # Serve docs at http://127.0.0.1:8000
make check         # Full local quality gate
```

## Commit Hygiene (No Unnecessary Pushes)

Before pushing, run:

```bash
make check
git status --short
```

Do not commit:

- generated output (`site/`)
- local environments (`.venv/`)
- OS/editor noise (`.DS_Store`, temporary files)
- secrets, tokens, private keys, credentials, `.env` files
- unrelated refactors or formatting-only churn outside your change scope

Only commit:

- files required for the feature/fix
- tests and docs that match the change
- minimal, reviewable diffs

## Definition of Done

A change is complete only when:

- quality checks pass (`make check`)
- docs are updated and build in strict mode
- behavior changes are tested
- operational and rollback impact is clear in the PR description

## Contributing

Use the full contribution process documented in `docs/contributing.md`.
