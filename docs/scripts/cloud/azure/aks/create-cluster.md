# create-cluster.sh

## Purpose
Create an AKS cluster with configurable node pool and networking defaults.

## Location
`cloud/azure/aks/create-cluster.sh`

## Preconditions
- Required tools: `bash`, `az`
- Required permissions: AKS create permissions in target resource group/subscription
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Cluster name |
| `--resource-group NAME` | Yes | N/A | Target resource group |
| `--location LOCATION` | No | resource-group default | Region override |
| `--subscription ID` | No | az default | Subscription override |
| `--node-count N` | No | `3` | Node count |
| `--node-vm-size SIZE` | No | `Standard_D4s_v5` | Node VM size |
| `--kubernetes-version VER` | No | latest supported | Kubernetes version |
| `--network-plugin NAME` | No | `azure` | `azure\|kubenet` |
| `--generate-ssh-keys` | No | `false` | Auto-generate SSH keys |
| `--dry-run` | No | `false` | Print command only |

## Scenarios
- Happy path: create a new AKS cluster for staging workloads.
- Common operational path: tune node size/count for an environment rollout.
- Failure path: invalid plugin value or missing create permissions.
- Recovery/rollback path: adjust parameters and rerun provisioning.

## Usage
```bash
cloud/azure/aks/create-cluster.sh --name aks-stg --resource-group rg-stg
cloud/azure/aks/create-cluster.sh --name aks-stg --resource-group rg-stg --node-count 4 --node-vm-size Standard_D8s_v5
```

## Behavior
- Main execution flow:
  - validates required identifiers and options
  - builds `az aks create` command with defaults/overrides
  - executes or prints in dry-run mode
- Idempotency notes: non-idempotent if cluster already exists.
- Side effects: provisions cluster control plane and node pool resources.

## Output
- Standard output format: native Azure CLI create output.
- Exit codes:
  - `0` success
  - `2` validation errors
  - non-zero on API/auth/quota failures

## Failure Modes
- Common errors and likely causes:
  - unsupported Kubernetes version
  - insufficient quota in region
  - resource-group/subscription mismatch
- Recovery and rollback steps:
  - revalidate version/region constraints
  - adjust VM size/count
  - retry with correct context

## Security Notes
- Secret handling: no secret flags expected.
- Least-privilege requirements: AKS create permissions scoped to target RG.
- Audit/logging expectations: cluster creation should tie to change approval.

## Testing
- Unit tests:
  - option validation and command construction
- Integration tests:
  - create small non-production AKS cluster
- Manual verification:
  - confirm cluster with `az aks show`
