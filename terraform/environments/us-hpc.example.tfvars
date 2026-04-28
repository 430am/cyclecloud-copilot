# US HPC profile — EXAMPLE FILE
# Copy this file to us-hpc.tfvars and customize values for your deployment.
# Do not commit us-hpc.tfvars; it is in .gitignore to protect secrets.
#
# Choose a region from this list based on current SKU availability for HBv3-v5 and NC/ND families:
# eastus2, southcentralus, westus2
# Validate at deployment time with:
# az vm list-skus --location <region> --all --output table | rg 'HB|NC|ND'

location = "southcentralus"

# Naming convention aligned with AzureTrace guidance:
# <resource-type>-<environment>-<workload>-<region-code>-<instance>
# Example: vm-prd-cclz-scus-01
name_prefix                  = "prd-cclz-scus-01"
resource_group_name          = "rg-prd-cclz-scus-01"
cyclecloud_vm_name           = "vm-prd-cclz-scus-01"
key_vault_name               = "kv-prd-cclz-scus-01"
bastion_name                 = "bas-prd-cclz-scus-01"
bastion_public_ip_name       = "pip-prd-cclz-scus-bas-01"
nat_gateway_name             = "nat-prd-cclz-scus-01"
nat_public_ip_name           = "pip-prd-cclz-scus-nat-01"
log_analytics_workspace_name = "law-prd-cclz-scus-01"
cyclecloud_uami_name         = "uami-prd-cclz-scus-01"
cyclecloud_custom_role_name  = "CycleCloud Custom Role prd scus"

# Storage accounts must be 3-24 chars, lowercase alphanumeric only.
locker_storage_account_name   = "stprdcclzscus01lk"
bootdiag_storage_account_name = "stprdcclzscus01bd"

anf_account_name = "anf-prd-cclz-scus-01"
anf_pool_name    = "pool-prd-cclz-scus-01"
anf_volume_name  = "vol-prd-cclz-scus-01"

# Network profile
vnet_address_space           = ["10.50.0.0/16"]
cyclecloud_subnet_cidr       = ["10.50.0.0/27"]
private_endpoint_subnet_cidr = ["10.50.0.32/27"]
bastion_subnet_cidr          = ["10.50.0.64/26"]
anf_delegated_subnet_cidr    = ["10.50.0.128/28"]
cluster_subnet_cidr          = ["10.50.2.0/23"]

# Keep CycleCloud server VM general-purpose.
cyclecloud_vm_size = "Standard_D4ds_v5"

# Optional common tags
tags = {
  environment = "prod"
  workload    = "cyclecloud"
  region      = "southcentralus"
  naming      = "rt-env-workload-region-instance"
  managed_by  = "terraform"
}

# Service principal credentials for Terraform to authenticate with Azure.
# Set these values or provide via environment variables (ARM_SUBSCRIPTION_ID, etc.).
# WARNING: Do not commit real credentials to version control.
# This example file is committed; the runtime file (us-hpc.tfvars) is in .gitignore.
ARM_SUBSCRIPTION_ID = "<subscription-id>"
ARM_CLIENT_ID       = "<service-principal-client-id>"
ARM_CLIENT_SECRET   = "<service-principal-client-secret>"
ARM_TENANT_ID       = "<azure-tenant-id>"
