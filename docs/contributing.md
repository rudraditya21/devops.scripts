# Contributing

This project accepts contributions for scripts, tests, documentation, and developer tooling.

## Ways to Contribute

- Report bugs
- Request new scripts or enhancements
- Improve docs and examples
- Submit new scripts and tests

## Before Opening an Issue

1. Search existing issues to avoid duplicates.
2. Confirm the behavior on the latest `main`.
3. Collect reproducible details (commands, logs, environment).

## Local Setup

1. Fork the repository on GitHub (`rudraditya21/devops.scripts` -> your account).
2. Clone your fork and install docs dependencies:

```bash
git clone https://github.com/<your-username>/devops.scripts.git
cd devops.scripts
make docs-install
```

Install required CLI tools for quality checks:

```bash
brew install shfmt shellcheck
```

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y shfmt shellcheck
```

## Fork and Branch Workflow

1. Fork the repository.
2. Clone your fork.
3. Add upstream remote:
   `git remote add upstream https://github.com/rudraditya21/devops.scripts.git`
4. Create a focused branch from latest `main`:
   `git checkout -b feat/<scope>-<short-name>`
5. Keep your branch updated with upstream `main`.

## Script Standards (Required)

- Use strict mode: `set -euo pipefail`
- Validate all inputs and required environment variables
- Provide `--help` usage with examples
- Add `--dry-run` for mutating operations
- Emit clear logs and explicit non-zero failures
- Keep scripts idempotent where feasible

## Testing and Validation (Required)

Run before opening a PR:

```bash
make format
make lint
make docs-build
make check
```

## Documentation Standards (Required)

For each script, add or update docs using `docs/script-spec.md`, including:

- Purpose and scope
- Preconditions and permissions
- Arguments and examples
- Failure modes and rollback guidance
- Security notes

## Commit and PR Standards

- Use clear commit messages (Conventional Commits style preferred), for example:
  - `feat(cloud/aws): add s3 lifecycle policy script`
  - `fix(shared): handle missing env var in retry helper`
- Keep PRs focused and small enough to review safely.
- Link related issue(s) in the PR description.
- Include validation evidence (commands run and outcomes).
- Document any operational risk and rollback considerations.

## PR Review Expectations

A PR is merge-ready only when:

- CI is green
- Formatting/lint/docs checks pass
- Documentation is complete
- Safety controls are present for mutating behavior
- Reviewer concerns are resolved

## Security Reporting

Do not open public issues for vulnerabilities. Report security issues privately to repository maintainers with reproduction details and impact assessment.
