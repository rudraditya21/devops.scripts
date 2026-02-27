# create-nat-gateway.sh

## Purpose
Create a NAT Gateway in a subnet with optional Elastic IP allocation and readiness waiting.

## Location
`cloud/aws/vpc/create-nat-gateway.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `ec2:CreateNatGateway`, `ec2:DescribeNatGateways`, optional `ec2:AllocateAddress`, `ec2:CreateTags`, `ec2:DescribeSubnets`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--subnet-id ID` | Yes | N/A | Subnet for NAT gateway |
| `--allocation-id ID` | No | empty | Existing EIP allocation ID |
| `--create-eip` | No | `true` | Auto-allocate EIP for public NAT |
| `--connectivity-type TYPE` | No | `public` | `public\|private` |
| `--name NAME` | No | empty | Name tag |
| `--tag KEY=VALUE` | No | none | Tag pair (repeatable) |
| `--tags CSV` | No | none | Comma-separated tag pairs |
| `--if-not-exists` | No | `false` | Reuse pending/available NAT in subnet |
| `--wait` / `--no-wait` | No | wait enabled | Wait for availability |
| `--timeout SEC` | No | `1200` | Wait timeout |
| `--poll-interval SEC` | No | `15` | Poll interval |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default | Profile override |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: NAT gateway is created and reaches `available`.
- Common operational path: create egress NAT for private route tables in new VPC stacks.
- Failure path: no free EIP, invalid subnet, or failed NAT state.
- Recovery/rollback path: delete failed NAT, release EIP if allocated, rerun with corrected subnet/quotas.

## Usage
```bash
cloud/aws/vpc/create-nat-gateway.sh --subnet-id subnet-0123456789abcdef0 --name prod-nat
cloud/aws/vpc/create-nat-gateway.sh --subnet-id subnet-0123456789abcdef0 --allocation-id eipalloc-0123456789abcdef0
cloud/aws/vpc/create-nat-gateway.sh --subnet-id subnet-0123456789abcdef0 --if-not-exists --dry-run
```

## Behavior
- Main execution flow:
  - validates subnet and mode
  - optionally reuses existing NAT in subnet
  - allocates EIP when needed
  - creates NAT and applies tags
  - optionally waits until state is `available`
- Idempotency notes: convergent with `--if-not-exists` for subnet-scoped NAT.
- Side effects: creates NAT gateway and optionally allocates billable Elastic IP.

## Output
- Standard output format: NAT gateway ID on stdout; logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/preconditions
  - non-zero on AWS API failures or wait timeout/failure state

## Failure Modes
- Common errors and likely causes:
  - subnet not found/inaccessible
  - EIP allocation failure/quota issues
  - NAT gateway enters `failed` state
- Recovery and rollback steps:
  - validate subnet and internet gateway prerequisites
  - increase quotas or provide explicit allocation ID
  - clean up failed NAT and rerun

## Security Notes
- Secret handling: none.
- Least-privilege requirements: scoped NAT/EIP create permissions only.
- Audit/logging expectations: NAT creation and EIP allocations should be tracked for cost/security review.

## Testing
- Unit tests:
  - input validation and mode constraints
  - reuse logic with `--if-not-exists`
- Integration tests:
  - public NAT create with auto EIP and wait path
- Manual verification:
  - `describe-nat-gateways` state and associated route table integration
