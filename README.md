# DevOps Scripts Library

Production-grade DevOps automation library organized by domain, with strict engineering standards for script quality, safety, and documentation.

## Goals

- Provide reusable scripts for real operational work across cloud, platform, data, CI/CD, security, and SRE.
- Keep every script deterministic, auditable, testable, and safe for enterprise environments.
- Ship complete documentation for each script through MkDocs.

## Repository Layout

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

## Quality Bar (Non-Negotiable)

Every production script must include:

- `set -euo pipefail`
- Input validation for all required arguments and environment variables
- Idempotent behavior where applicable
- Structured logging with timestamps and clear error messages
- Safe mode support (`--dry-run`) for mutating operations
- Explicit exit codes and failure paths
- Usage/help output with examples
- Tests (unit/integration as applicable)
- Matching documentation page in `docs/`

## Documentation Setup (MkDocs)

- Config file: `mkdocs.yml`
- Docs source folder: `docs/`

Local docs workflow:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements-docs.txt
mkdocs serve
mkdocs build --strict
```

## Contribution Workflow

1. Add script under the correct domain folder.
2. Add tests for the script.
3. Add/update docs page under `docs/`.
4. Run local quality checks (lint + tests + docs build).
5. Submit PR with usage examples and operational notes.

## Current Scope

This repository is being built iteratively. Scripts and docs are added in phases, with each new script held to the same quality and documentation standards.
