# create-route-tables.sh

## Purpose
Create and wire public/private route tables, default routes, and subnet associations for a VPC.

## Location
`cloud/aws/vpc/create-route-tables.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `ec2:CreateRouteTable`, `ec2:CreateRoute`, `ec2:AssociateRouteTable`, `ec2:CreateTags`, `ec2:Describe*`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--vpc-id ID` | Yes | N/A | Target VPC |
| `--name-prefix PREFIX` | No | `vpc` | Prefix for route table names |
| `--public-subnet-ids CSV` | Cond. | none | Subnets for public route table |
| `--private-subnet-ids CSV` | Cond. | none | Subnets for private route table |
| `--internet-gateway-id ID` | Cond. | none | Required when public subnets are provided |
| `--nat-gateway-id ID` | Cond. | none | Required when private subnets are provided |
| `--tag KEY=VALUE` | No | none | Tag pair applied to route tables |
| `--tags CSV` | No | none | Comma-separated tag pairs |
| `--if-not-exists` | No | `false` | Reuse route tables by Name tag |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default | Profile override |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: route tables are created, default routes added, subnets associated.
- Common operational path: post-subnet wiring in VPC stack provisioning pipeline.
- Failure path: missing IGW/NAT IDs, invalid subnet IDs, or route association conflicts.
- Recovery/rollback path: disassociate/replace conflicting route tables and rerun.

## Usage
```bash
cloud/aws/vpc/create-route-tables.sh --vpc-id vpc-0123456789abcdef0 --name-prefix prod --public-subnet-ids subnet-a,subnet-b --internet-gateway-id igw-0123456789abcdef0 --private-subnet-ids subnet-c,subnet-d --nat-gateway-id nat-0123456789abcdef0
cloud/aws/vpc/create-route-tables.sh --vpc-id vpc-0123456789abcdef0 --public-subnet-ids subnet-a --internet-gateway-id igw-0123456789abcdef0 --if-not-exists
cloud/aws/vpc/create-route-tables.sh --vpc-id vpc-0123456789abcdef0 --private-subnet-ids subnet-c --nat-gateway-id nat-0123456789abcdef0 --dry-run
```

## Behavior
- Main execution flow:
  - validates input wiring requirements
  - creates/reuses public and/or private route tables
  - ensures default routes (`0.0.0.0/0`) for IGW/NAT targets
  - associates requested subnets
- Idempotency notes: route creation handles existing default routes; reuse enabled with `--if-not-exists`.
- Side effects: modifies route tables, routes, and subnet associations.

## Output
- Standard output format: table of route table type, ID, and association count.
- Exit codes:
  - `0` success
  - `2` invalid arguments/precondition failures
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - missing required gateway ID for subnet class
  - route already bound to conflicting targets
  - subnet association conflicts
- Recovery and rollback steps:
  - validate target architecture (public via IGW, private via NAT)
  - inspect existing associations and rewire intentionally
  - rerun with `--if-not-exists` for convergent behavior

## Security Notes
- Secret handling: none.
- Least-privilege requirements: scope EC2 networking permissions to intended VPC/subnets.
- Audit/logging expectations: route and association changes should be peer-reviewed and traceable.

## Testing
- Unit tests:
  - CSV parser and dependency validation logic
- Integration tests:
  - full public+private route table wiring in test VPC
- Manual verification:
  - `describe-route-tables` route/association inspection
