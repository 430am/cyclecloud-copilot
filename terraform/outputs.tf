output "resource_group_name" {
  description = "Resource group name for the landing zone."
  value       = module.resource_group.name
}

output "vnet_id" {
  description = "Virtual network resource ID."
  value       = module.network.resource_id
}

output "cluster_subnet_id" {
  description = "Cluster subnet resource ID."
  value       = module.network.subnets["cluster"].resource_id
}

output "cyclecloud_vm_resource_id" {
  description = "CycleCloud VM resource ID."
  value       = module.cyclecloud_vm.resource_id
}

output "cyclecloud_vm_private_ip" {
  description = "CycleCloud VM private IP address."
  value       = module.cyclecloud_vm.virtual_machine_azurerm.private_ip_address
}

output "key_vault_id" {
  description = "Key Vault resource ID."
  value       = module.key_vault.resource_id
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = module.key_vault.uri
}

output "bastion_id" {
  description = "Azure Bastion resource ID."
  value       = azurerm_bastion_host.cyclecloud.id
}

output "nat_gateway_id" {
  description = "NAT Gateway resource ID."
  value       = azurerm_nat_gateway.cyclecloud.id
}

output "locker_storage_account_id" {
  description = "Storage account resource ID for CycleCloud locker."
  value       = azurerm_storage_account.locker.id
}

output "bootdiag_storage_account_id" {
  description = "Storage account resource ID for VM boot diagnostics."
  value       = azurerm_storage_account.bootdiag.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.cyclecloud.id
}

output "cyclecloud_uami_id" {
  description = "CycleCloud user-assigned managed identity resource ID."
  value       = azurerm_user_assigned_identity.cyclecloud.id
}

output "anf_volume_mount_ip" {
  description = "ANF mount target IP for NFS client mounts."
  value       = azurerm_netapp_volume.cyclecloud.mount_ip_addresses[0]
}

output "anf_export_path" {
  description = "ANF volume export path."
  value       = azurerm_netapp_volume.cyclecloud.volume_path
}

output "generated_ssh_public_key_secret_id" {
  description = "Key Vault secret ID for the generated public key."
  value       = module.key_vault.secrets_resource_ids["cyclecloud_ssh_public"].id
}

output "generated_ssh_private_key_secret_id" {
  description = "Key Vault secret ID for the generated private key."
  value       = module.key_vault.secrets_resource_ids["cyclecloud_ssh_private"].id
  sensitive   = true
}
