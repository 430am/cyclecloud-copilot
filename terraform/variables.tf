variable "name_prefix" {
  description = "Prefix used when naming resources."
  type        = string
  default     = "cc-lz"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "southcentralus"
}

variable "resource_group_name" {
  description = "Resource group name for the landing zone."
  type        = string
  default     = "rg-cc-lz-scus"
}

variable "vnet_address_space" {
  description = "Address space for the landing zone virtual network."
  type        = list(string)
  default     = ["10.50.0.0/16"]
}

variable "cyclecloud_subnet_cidr" {
  description = "CIDR for the CycleCloud VM subnet."
  type        = list(string)
  default     = ["10.50.0.0/27"]
}

variable "cluster_subnet_cidr" {
  description = "CIDR for CycleCloud cluster resources."
  type        = list(string)
  default     = ["10.50.2.0/23"]
}

variable "private_endpoint_subnet_cidr" {
  description = "CIDR for private endpoints."
  type        = list(string)
  default     = ["10.50.0.32/27"]
}

variable "bastion_subnet_cidr" {
  description = "CIDR for Azure Bastion subnet (must be /26 or larger)."
  type        = list(string)
  default     = ["10.50.0.64/26"]
}

variable "anf_delegated_subnet_cidr" {
  description = "CIDR for Azure NetApp Files delegated subnet."
  type        = list(string)
  default     = ["10.50.0.128/28"]
}

variable "key_vault_name" {
  description = "Name of the Key Vault used for SSH key storage."
  type        = string
  default     = "kv-cclz-scus"
}

variable "cyclecloud_vm_name" {
  description = "Name of the CycleCloud virtual machine."
  type        = string
  default     = "vm-cyclecloud"
}

variable "cyclecloud_vm_size" {
  description = "SKU for the CycleCloud virtual machine."
  type        = string
  default     = "Standard_D4ds_v5"
}

variable "cyclecloud_vm_zone" {
  description = "Availability zone for the VM. Set null if unsupported in target region."
  type        = string
  default     = "1"
}

variable "admin_username" {
  description = "Admin username for the CycleCloud VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_key_bits" {
  description = "Bit size for generated RSA SSH key."
  type        = number
  default     = 4096
}

variable "cyclecloud_package_name" {
  description = "APT package name for CycleCloud."
  type        = string
  default     = "cyclecloud8"
}

variable "anf_account_name" {
  description = "Azure NetApp Files account name."
  type        = string
  default     = "anfcclz01"
}

variable "anf_pool_name" {
  description = "Azure NetApp Files capacity pool name."
  type        = string
  default     = "anfpool01"
}

variable "anf_volume_name" {
  description = "Azure NetApp Files volume name."
  type        = string
  default     = "anfvol01"
}

variable "anf_volume_path" {
  description = "Azure NetApp Files export path."
  type        = string
  default     = "cyclecloud"
}

variable "anf_pool_size_tb" {
  description = "Capacity pool size in TiB."
  type        = number
  default     = 4
}

variable "anf_volume_quota_gb" {
  description = "ANF volume quota in GiB."
  type        = number
  default     = 1024
}

variable "anf_service_level" {
  description = "ANF service level (Standard, Premium, or Ultra)."
  type        = string
  default     = "Standard"
}

variable "locker_storage_account_name" {
  description = "Storage account for CycleCloud locker content."
  type        = string
  default     = "stcclocker01"
}

variable "bootdiag_storage_account_name" {
  description = "Storage account for VM boot diagnostics."
  type        = string
  default     = "stccbootdiag01"
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace for monitoring."
  type        = string
  default     = "law-cc-lz"
}

variable "nat_gateway_name" {
  description = "Name of NAT Gateway for default outbound access."
  type        = string
  default     = "nat-cc-lz"
}

variable "nat_public_ip_name" {
  description = "Name of NAT Gateway public IP."
  type        = string
  default     = "pip-nat-cc-lz"
}

variable "bastion_name" {
  description = "Azure Bastion host name."
  type        = string
  default     = "bas-cc-lz"
}

variable "bastion_public_ip_name" {
  description = "Azure Bastion public IP name."
  type        = string
  default     = "pip-bas-cc-lz"
}

variable "cyclecloud_uami_name" {
  description = "User-assigned managed identity for CycleCloud orchestration."
  type        = string
  default     = "uami-cyclecloud"
}

variable "cyclecloud_custom_role_name" {
  description = "Custom role name for CycleCloud permissions."
  type        = string
  default     = "CycleCloud Custom Role"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    workload    = "cyclecloud"
    environment = "landing-zone"
    managed_by  = "terraform"
  }
}
