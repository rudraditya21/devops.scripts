# create-vpc.sh

## Purpose
Create an AWS VPC with configurable CIDR, DNS attributes, tenancy, and tags.

## Location
`cloud/aws/vpc/create-vpc.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `ec2:CreateVpc`, `ec2:ModifyVpcAttribute`, `ec2:CreateTags`, `ec2:DescribeVpcs`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cidr CIDR` | Yes | N/A | VPC CIDR block |
| `--name NAME` | No | empty | Name tag |
| `--tenancy MODE` | No | `default` | `default\|dedicated` |
| `--enable-dns-support BOOL` | No | `true` | Enable DNS resolution |
| `--enable-dns-hostnames BOOL` | No | `true` | Enable DNS hostnames |
| `--tag KEY=VALUE` | No | none | Tag pair (repeatable) |
| `--tags CSV` | No | none | Comma-separated tag pairs |
| `--if-not-exists` | No | `false` | Reuse matching VPC by CIDR/name |
| `--wait` / `--no-wait` | No | wait enabled | Wait for available state |
| `--timeout SEC` | No | `180` | Wait timeout |
| `--poll-interval SEC` | No | `5` | Wait polling interval |
| `--region REGION` | No | AWS default | Region override |
| `--profile PROFILE` | No | AWS default | Profile override |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: VPC created, tagged, DNS settings applied, state becomes `available`.
- Common operational path: bootstrap network foundation in environment provisioning pipelines.
- Failure path: overlapping/invalid CIDR, duplicate VPC match, or missing EC2 permissions.
- Recovery/rollback path: delete newly created VPC stack and rerun with corrected parameters.

## Usage
```bash
cloud/aws/vpc/create-vpc.sh --cidr 10.20.0.0/16 --name prod-core --region us-east-1
cloud/aws/vpc/create-vpc.sh --cidr 10.30.0.0/16 --name staging-core --tag Environment=staging
cloud/aws/vpc/create-vpc.sh --cidr 10.40.0.0/16 --if-not-exists --dry-run
```

## Behavior
- Main execution flow:
  - validates CIDR/options
  - optionally reuses existing VPC when `--if-not-exists` is set
  - creates VPC and applies tags + DNS attributes
  - optionally waits for availability
- Idempotency notes: convergent with `--if-not-exists`; otherwise duplicate matches fail.
- Side effects: creates VPC resource and modifies VPC attributes.

## Output
- Standard output format: VPC ID on stdout; logs on stderr.
- Exit codes:
  - `0` success
  - `2` argument/precondition failure
  - non-zero on AWS API errors

## Failure Modes
- Common errors and likely causes:
  - invalid CIDR format
  - VPC already exists when not using `--if-not-exists`
  - permission denied on create/modify/tag operations
- Recovery and rollback steps:
  - fix CIDR/inputs and retry
  - use `--if-not-exists` in convergent pipelines
  - validate IAM role permissions and account context

## Security Notes
- Secret handling: no secrets processed.
- Least-privilege requirements: scope to required EC2 create/modify/tag actions only.
- Audit/logging expectations: VPC creation and attribute changes should be captured in CloudTrail.

## Testing
- Unit tests:
  - option validation and boolean normalization
  - existing-VPC reuse logic
- Integration tests:
  - create path with and without wait
- Manual verification:
  - `describe-vpcs` + `describe-vpc-attribute` checks
