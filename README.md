# cyclecloud-copilot

Terraform landing zone for Azure CycleCloud with:

- Azure Verified Modules (AVM) for resource group, virtual network, key vault, and VM
- TLS-generated SSH keys stored in Azure Key Vault
- Cloud-init based VM customization (CycleCloud, Azure CLI, CycleCloud CLI)
- Ubuntu 24.04 server image for the CycleCloud VM
- Azure NetApp Files for NFS-backed CycleCloud storage
- Azure Bastion (Standard) with SSH tunneling support
- NAT Gateway for default outbound access from compute subnets
- Dedicated storage accounts for CycleCloud locker and VM boot diagnostics
- Log Analytics workspace with Azure Monitor Private Link scope
- Private endpoint-enabled PaaS services with private DNS integration
- User-assigned managed identity with custom CycleCloud role assignment
- Resource-level diagnostic settings piped to Log Analytics for supported resources

## Architecture Summary

- Resource Group: AVM module
- Network: AVM virtual network module with five subnets
	- CycleCloud VM subnet (default: 10.50.0.0/27)
	- Private endpoint subnet (default: 10.50.0.32/27)
	- Azure Bastion subnet (default: 10.50.0.64/26)
	- ANF delegated subnet (default: 10.50.0.128/28)
	- Cluster resources subnet (default: 10.50.2.0/23)
- Key Vault: AVM key vault module with public network disabled and private endpoint
- SSH Keys: Created by `hashicorp/tls`, stored as Key Vault secrets
- CycleCloud VM: AVM VM module on Ubuntu 24.04 with cloud-init customization
- Access: Azure Bastion tunneling for SSH instead of public IP exposure
- Outbound: NAT Gateway association for CycleCloud and cluster subnets
- NFS Storage: Azure NetApp Files account + pool + volume
- Locker and diagnostics: private endpoint-enabled blob storage accounts
- Monitoring: Log Analytics + Azure Monitor Private Link endpoint
- Identity: user-assigned managed identity with custom CycleCloud role scoped at subscription

Note: Azure NetApp Files data access is delivered through delegated subnets and NFS mount targets. Private endpoints are configured for Key Vault, storage accounts, and Azure Monitor private link scope.

## Folder Layout

- `terraform/terraform.tf`: Terraform + provider versions
- `terraform/variables.tf`: Input variables
- `terraform/locals.tf`: Naming and common tags
- `terraform/main.tf`: Modules and resources
- `terraform/outputs.tf`: Exported values
- `terraform/environments/us-hpc.tfvars`: US HPC region and naming profile
- `terraform/cloud-init/cyclecloud.yaml.tftpl`: Cloud-init template

## US HPC tfvars Profile

Use the provided profile file:

```bash
cd terraform
terraform plan -var-file="environments/us-hpc.tfvars"
```

The profile file at `terraform/environments/us-hpc.tfvars` includes:

- Region targeting guidance for US regions commonly used for HB/NC/ND HPC workloads.
- Naming convention aligned with AzureTrace pattern:
	- `<resource-type>-<environment>-<workload>-<region-code>-<instance>`
- Resource name overrides and storage-account-safe names.
- CIDR defaults for the current landing zone subnet model.

## Safe Secrets Workflow

Use a committed example file and a local untracked runtime file:

- Commit: `terraform/environments/us-hpc.example.tfvars` with placeholder values only.
- Keep local only: `terraform/environments/us-hpc.tfvars` with real values.

Recommended flow:

```bash
cp terraform/environments/us-hpc.example.tfvars terraform/environments/us-hpc.tfvars
# edit terraform/environments/us-hpc.tfvars with environment-specific values
cd terraform
terraform plan -var-file="environments/us-hpc.tfvars"
```

The repository `.gitignore` is configured to avoid committing `.tfvars` and other common secret-bearing files.

## Prerequisites

- Terraform `>= 1.9`
- Azure CLI authenticated to target tenant/subscription
- Environment variable set for provider subscription scoping:

```bash
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

Optional but common:

```bash
export ARM_TENANT_ID="<tenant-id>"
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<client-secret>"
```

## Deploy

```bash
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

## Key Inputs to Customize

- `resource_group_name`
- `location`
- `vnet_address_space` (default `10.50.0.0/16`)
- `cluster_subnet_cidr` (default `/23`)
- `key_vault_name`
- `cyclecloud_vm_name`
- `cyclecloud_vm_size`
- `cyclecloud_vm_zone`
- `anf_*` sizing and naming variables
- `locker_storage_account_name`
- `bootdiag_storage_account_name`
- `log_analytics_workspace_name`
- `cyclecloud_uami_name`
- `cyclecloud_custom_role_name`
- subnet CIDRs

## Post-Deploy

- Retrieve secret IDs from outputs:
	- `generated_ssh_public_key_secret_id`
	- `generated_ssh_private_key_secret_id`
- Connect to the VM over private connectivity from a peered network/jump host.
- Verify cloud-init logs on the VM:

```bash
sudo cloud-init status --wait
sudo tail -n 200 /var/log/cloud-init-output.log
```

## Security Notes

- Key Vault public network access is disabled.
- Key Vault access uses RBAC and private endpoint integration.
- Sensitive key material is marked sensitive in outputs.
- VM is provisioned without public IP by default.
- SSH access is intended through Azure Bastion tunneling.
- Storage account access is private endpoint only.

## Diagnostics Coverage

Diagnostics are sent to Log Analytics for supported resources, including:

- Virtual network (via AVM diagnostic settings)
- Key Vault (via AVM diagnostic settings)
- CycleCloud VM (via AVM VM diagnostic settings)
- Bastion host
- NAT Gateway
- Locker storage blob service
- Boot diagnostics storage blob service
- Azure NetApp Files account, pool, and volume
