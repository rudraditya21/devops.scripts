# DevOps Scripts Library

This documentation site tracks all scripts in the repository with operationally complete guidance.

## What You Can Expect

- Clear scope and ownership for each script
- Safe execution guidance and rollback steps
- Required permissions, dependencies, and environment variables
- Examples for real production scenarios
- Failure modes, observability hooks, and troubleshooting notes

## Domains

- Cloud (`cloud/`)
- Containers (`containers/`)
- Infrastructure (`infrastructure/`)
- CI/CD (`cicd/`)
- Databases (`databases/`)
- Monitoring (`monitoring/`)
- Security (`security/`)
- Networking (`networking/`)
- Backup (`backup/`)
- Cost (`cost/`)
- Git (`git/`)
- SRE (`sre/`)
- Setup (`setup/`)
- Shared utilities (`shared/`)

## Build Docs Locally

```bash
make docs-install
make docs-serve
```

## Documentation Policy

No script is considered complete unless its documentation page is complete and reviewed.
