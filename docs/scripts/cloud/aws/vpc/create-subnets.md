# create-subnets.sh

## Purpose
Create one or more VPC subnets from structured subnet specs with optional public IP mapping.

## Location
`cloud/aws/vpc/create-subnets.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `ec2:CreateSubnet`, `ec2:ModifySubnetAttribute`, `ec2:CreateTags`, `ec2:DescribeSubnets`, `ec2:DescribeVpcs`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--vpc-id ID` | Yes | N/A | Target VPC ID |
| `--subnet SPEC` | Yes | N/A | Repeatable spec: `name=...,cidr=...,az=...,public=true|false` |
| `--tag KEY=VALUE` | No | none | Global tag pair for created subnets |
| `--tags CSV` | No | none | Comma-separated global tags |
| `--if-not-exists` | No | `false` | Reuse subnet if CIDR already exists in VPC |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default | Profile override |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: all declared subnet specs are created and tagged.
- Common operational path: create public/private AZ-specific subnet sets during VPC stack bootstrap.
- Failure path: malformed spec, CIDR conflict, or inaccessible VPC.
- Recovery/rollback path: delete wrongly created subnets and rerun with corrected specs.

## Usage
```bash
cloud/aws/vpc/create-subnets.sh --vpc-id vpc-0123456789abcdef0 --subnet "name=public-a,cidr=10.20.1.0/24,az=us-east-1a,public=true" --subnet "name=private-a,cidr=10.20.11.0/24,az=us-east-1a,public=false"
cloud/aws/vpc/create-subnets.sh --vpc-id vpc-0123456789abcdef0 --subnet "cidr=10.20.2.0/24,az=us-east-1b,public=true" --if-not-exists
cloud/aws/vpc/create-subnets.sh --vpc-id vpc-0123456789abcdef0 --subnet "name=private-b,cidr=10.20.12.0/24,az=us-east-1b" --dry-run
```

## Behavior
- Main execution flow:
  - parses and validates each subnet spec
  - checks for existing CIDR in VPC
  - creates subnets, toggles public IP mapping when requested
  - applies Name/global tags
- Idempotency notes: convergent with `--if-not-exists` for CIDR matches.
- Side effects: creates subnets and updates subnet attributes.

## Output
- Standard output format: table with subnet ID/CIDR/AZ/public/status.
- Exit codes:
  - `0` success
  - `2` invalid arguments/precondition failures
  - non-zero on AWS API errors

## Failure Modes
- Common errors and likely causes:
  - missing `cidr` field in spec
  - duplicate/overlapping CIDR in VPC
  - invalid subnet/AZ values or denied create permissions
- Recovery and rollback steps:
  - validate each spec before execution
  - use `--if-not-exists` for rerunnable pipelines
  - inspect failed subnet IDs and clean up as needed

## Security Notes
- Secret handling: none.
- Least-privilege requirements: limit subnet create/modify/tag actions to scoped VPCs.
- Audit/logging expectations: subnet creation and public-IP-on-launch changes should be auditable.

## Testing
- Unit tests:
  - subnet spec parser and validation logic
  - `public=true|false` attribute behavior
- Integration tests:
  - mixed public/private subnet creation across AZs
- Manual verification:
  - `describe-subnets` and map-public-ip attribute checks
