# vpc-healthcheck.sh

## Purpose
Run operational health checks for a VPC, including DNS, subnet posture, IGW/NAT presence, and route-table counts.

## Location
`cloud/aws/vpc/vpc-healthcheck.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: read-only EC2 describe and VPC attribute APIs
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--vpc-id ID` | Yes | N/A | VPC to evaluate |
| `--expected-public-subnets N` | No | unset | Expected public subnet count |
| `--expected-private-subnets N` | No | unset | Expected private subnet count |
| `--require-nat` | No | `false` | Fail if no available NAT gateway |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default | Profile override |
| `--strict` | No | `false` | Exit non-zero on warnings |
| `--json` | No | `false` | Emit JSON report |

## Scenarios
- Happy path: VPC passes readiness checks with all core components healthy.
- Common operational path: preflight gate before provisioning workloads into VPC.
- Failure path: missing NAT/IGW, disabled DNS attributes, or missing subnets.
- Recovery/rollback path: remediate missing network components and rerun checks.

## Usage
```bash
cloud/aws/vpc/vpc-healthcheck.sh --vpc-id vpc-0123456789abcdef0
cloud/aws/vpc/vpc-healthcheck.sh --vpc-id vpc-0123456789abcdef0 --expected-public-subnets 2 --expected-private-subnets 2 --require-nat
cloud/aws/vpc/vpc-healthcheck.sh --vpc-id vpc-0123456789abcdef0 --json --strict
```

## Behavior
- Main execution flow:
  - validates AWS CLI and VPC visibility
  - checks VPC state and DNS support/hostnames attributes
  - checks IGW attachment and NAT availability
  - checks subnet totals/public/private split and optional expectations
  - emits PASS/WARN/FAIL summary
- Idempotency notes: read-only diagnostic workflow.
- Side effects: none.

## Output
- Standard output format: table by default, JSON with `--json`.
- Exit codes:
  - `0` no fail checks (and no warns in strict mode)
  - `1` fail checks present or strict-mode warnings
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - VPC not found/inaccessible
  - DNS attributes disabled unexpectedly
  - missing NAT/IGW/subnet components
- Recovery and rollback steps:
  - validate account/region/profile context
  - apply network baseline resources (IGW, NAT, subnets, routes)
  - rerun healthcheck and compare summary deltas

## Security Notes
- Secret handling: none.
- Least-privilege requirements: read-only EC2 permissions sufficient.
- Audit/logging expectations: preflight reports should be retained for release/change evidence.

## Testing
- Unit tests:
  - check aggregation and strict-mode exit behavior
- Integration tests:
  - healthy vs degraded VPC fixtures in sandbox
- Manual verification:
  - cross-check with EC2 console/network topology views
