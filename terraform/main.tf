data "azurerm_client_config" "current" {}

data "cloudinit_config" "cyclecloud" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cyclecloud-bootstrap.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init/cyclecloud.yaml.tftpl", {
      anf_mount_target        = azurerm_netapp_volume.cyclecloud.mount_ip_addresses[0]
      anf_volume_path         = var.anf_volume_path
      cyclecloud_package_name = var.cyclecloud_package_name
    })
  }
}

resource "tls_private_key" "cyclecloud_admin" {
  algorithm = "RSA"
  rsa_bits  = var.ssh_key_bits
}

resource "azurerm_user_assigned_identity" "cyclecloud" {
  name                = var.cyclecloud_uami_name
  resource_group_name = module.resource_group.name
  location            = var.location
  tags                = local.common_tags
}

resource "azurerm_role_definition" "cyclecloud_custom" {
  name        = var.cyclecloud_custom_role_name
  scope       = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  description = "Custom role for CycleCloud managed identity based on CycleCloud documentation."

  permissions {
    actions = [
      "Microsoft.Authorization/*/read",
      "Microsoft.Authorization/roleAssignments/*",
      "Microsoft.Authorization/roleDefinitions/*",
      "Microsoft.Commerce/RateCard/read",
      "Microsoft.Compute/*/read",
      "Microsoft.Compute/availabilitySets/*",
      "Microsoft.Compute/disks/*",
      "Microsoft.Compute/images/read",
      "Microsoft.Compute/locations/usages/read",
      "Microsoft.Compute/register/action",
      "Microsoft.Compute/skus/read",
      "Microsoft.Compute/virtualMachines/*",
      "Microsoft.Compute/virtualMachineScaleSets/*",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/*",
      "Microsoft.ManagedIdentity/userAssignedIdentities/*/read",
      "Microsoft.ManagedIdentity/userAssignedIdentities/*/assign/action",
      "Microsoft.MarketplaceOrdering/offertypes/publishers/offers/plans/agreements/read",
      "Microsoft.MarketplaceOrdering/offertypes/publishers/offers/plans/agreements/write",
      "Microsoft.Network/*/read",
      "Microsoft.Network/locations/*/read",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/networkInterfaces/write",
      "Microsoft.Network/networkInterfaces/delete",
      "Microsoft.Network/networkInterfaces/join/action",
      "Microsoft.Network/networkSecurityGroups/read",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Network/networkSecurityGroups/delete",
      "Microsoft.Network/networkSecurityGroups/join/action",
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/publicIPAddresses/write",
      "Microsoft.Network/publicIPAddresses/delete",
      "Microsoft.Network/publicIPAddresses/join/action",
      "Microsoft.Network/register/action",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Resources/deployments/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",
      "Microsoft.Resources/subscriptions/resourceGroups/resources/read",
      "Microsoft.Resources/subscriptions/operationresults/read",
      "Microsoft.Storage/*/read",
      "Microsoft.Storage/checknameavailability/read",
      "Microsoft.Storage/register/action",
      "Microsoft.Storage/storageAccounts/blobServices/containers/delete",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/write",
      "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/listKeys/action",
      "Microsoft.Storage/storageAccounts/write"
    ]

    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/move/action",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action"
    ]
  }

  assignable_scopes = [
    "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  ]
}

resource "azurerm_role_assignment" "cyclecloud_custom" {
  scope              = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_id = azurerm_role_definition.cyclecloud_custom.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.cyclecloud.principal_id
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  name             = var.resource_group_name
  location         = var.location
  tags             = local.common_tags
  enable_telemetry = false
}

resource "azurerm_public_ip" "nat" {
  name                = var.nat_public_ip_name
  location            = var.location
  resource_group_name = module.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway" "cyclecloud" {
  name                    = var.nat_gateway_name
  location                = var.location
  resource_group_name     = module.resource_group.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "cyclecloud" {
  nat_gateway_id       = azurerm_nat_gateway.cyclecloud.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

module "network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  name             = local.names.vnet
  location         = var.location
  parent_id        = module.resource_group.resource_id
  address_space    = toset(var.vnet_address_space)
  tags             = local.common_tags
  enable_telemetry = false
  diagnostic_settings = {
    vnet = {
      name                  = "diag-${local.names.vnet}"
      workspace_resource_id = azurerm_log_analytics_workspace.cyclecloud.id
    }
  }

  subnets = {
    cyclecloud = {
      name             = local.names.cyclecloud_subnet
      address_prefixes = var.cyclecloud_subnet_cidr
      nat_gateway = {
        id = azurerm_nat_gateway.cyclecloud.id
      }
    }
    cluster = {
      name             = local.names.cluster_subnet
      address_prefixes = var.cluster_subnet_cidr
      nat_gateway = {
        id = azurerm_nat_gateway.cyclecloud.id
      }
    }
    private_endpoints = {
      name                              = local.names.private_endpoint_sub
      address_prefixes                  = var.private_endpoint_subnet_cidr
      private_endpoint_network_policies = "Disabled"
    }
    bastion = {
      name             = local.names.bastion_subnet
      address_prefixes = var.bastion_subnet_cidr
    }
    anf = {
      name             = local.names.anf_subnet
      address_prefixes = var.anf_delegated_subnet_cidr
      delegations = [
        {
          name = "anf-delegation"
          service_delegation = {
            name = "Microsoft.Netapp/volumes"
          }
        }
      ]
    }
  }
}

resource "azurerm_public_ip" "bastion" {
  name                = var.bastion_public_ip_name
  location            = var.location
  resource_group_name = module.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_bastion_host" "cyclecloud" {
  name                = var.bastion_name
  location            = var.location
  resource_group_name = module.resource_group.name
  sku                 = "Standard"
  tunneling_enabled   = true
  ip_connect_enabled  = true
  tags                = local.common_tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = module.network.subnets["bastion"].resource_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = local.names.private_dns_zone_kv
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${var.name_prefix}-kv-dns-link"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = module.network.resource_id
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = local.names.private_dns_zone_blob
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${var.name_prefix}-blob-dns-link"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = module.network.resource_id
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone" "monitor" {
  name                = local.names.private_dns_zone_monitor
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "oms" {
  name                = local.names.private_dns_zone_oms
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "ods" {
  name                = local.names.private_dns_zone_ods
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "agentsvc" {
  name                = local.names.private_dns_zone_agentsvc
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor" {
  name                  = "${var.name_prefix}-monitor-dns-link"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.monitor.name
  virtual_network_id    = module.network.resource_id
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "oms" {
  name                  = "${var.name_prefix}-oms-dns-link"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.oms.name
  virtual_network_id    = module.network.resource_id
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ods" {
  name                  = "${var.name_prefix}-ods-dns-link"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.ods.name
  virtual_network_id    = module.network.resource_id
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "agentsvc" {
  name                  = "${var.name_prefix}-agentsvc-dns-link"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.agentsvc.name
  virtual_network_id    = module.network.resource_id
  tags                  = local.common_tags
}

module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"

  name                = var.key_vault_name
  location            = var.location
  resource_group_name = module.resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  public_network_access_enabled = false
  network_acls = {
    default_action = "Deny"
    bypass         = "None"
  }

  role_assignments = {
    current_user = {
      role_definition_id_or_name = "Key Vault Administrator"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }

  secrets = {
    cyclecloud_ssh_public = {
      name         = "cyclecloud-ssh-public"
      content_type = "text/plain"
    }
    cyclecloud_ssh_private = {
      name         = "cyclecloud-ssh-private"
      content_type = "text/plain"
    }
  }

  secrets_value = {
    cyclecloud_ssh_public  = tls_private_key.cyclecloud_admin.public_key_openssh
    cyclecloud_ssh_private = tls_private_key.cyclecloud_admin.private_key_pem
  }

  private_endpoints = {
    keyvault = {
      name                          = local.names.keyvault_pe
      subnet_resource_id            = module.network.subnets["private_endpoints"].resource_id
      private_dns_zone_resource_ids = toset([azurerm_private_dns_zone.keyvault.id])
    }
  }

  diagnostic_settings = {
    keyvault = {
      name                  = "diag-${var.key_vault_name}"
      workspace_resource_id = azurerm_log_analytics_workspace.cyclecloud.id
    }
  }

  tags             = local.common_tags
  enable_telemetry = false
}

resource "azurerm_storage_account" "locker" {
  name                            = var.locker_storage_account_name
  resource_group_name             = module.resource_group.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  tags                            = local.common_tags
}

resource "azurerm_storage_account" "bootdiag" {
  name                            = var.bootdiag_storage_account_name
  resource_group_name             = module.resource_group.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  tags                            = local.common_tags
}

resource "azurerm_private_endpoint" "locker_blob" {
  name                = local.names.locker_pe
  location            = var.location
  resource_group_name = module.resource_group.name
  subnet_id           = module.network.subnets["private_endpoints"].resource_id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${local.names.locker_pe}-blob"
    private_connection_resource_id = azurerm_storage_account.locker.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_private_endpoint" "bootdiag_blob" {
  name                = local.names.bootdiag_pe
  location            = var.location
  resource_group_name = module.resource_group.name
  subnet_id           = module.network.subnets["private_endpoints"].resource_id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${local.names.bootdiag_pe}-blob"
    private_connection_resource_id = azurerm_storage_account.bootdiag.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_log_analytics_workspace" "cyclecloud" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = module.resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_monitor_private_link_scope" "cyclecloud" {
  name                = "${var.name_prefix}-ampls"
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_monitor_private_link_scoped_service" "log_analytics" {
  name                = "${var.name_prefix}-law"
  resource_group_name = module.resource_group.name
  scope_name          = azurerm_monitor_private_link_scope.cyclecloud.name
  linked_resource_id  = azurerm_log_analytics_workspace.cyclecloud.id
}

resource "azurerm_private_endpoint" "monitor" {
  name                = local.names.monitor_pe
  location            = var.location
  resource_group_name = module.resource_group.name
  subnet_id           = module.network.subnets["private_endpoints"].resource_id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${local.names.monitor_pe}-pls"
    private_connection_resource_id = azurerm_monitor_private_link_scope.cyclecloud.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.monitor.id,
      azurerm_private_dns_zone.oms.id,
      azurerm_private_dns_zone.ods.id,
      azurerm_private_dns_zone.agentsvc.id
    ]
  }
}

resource "azurerm_netapp_account" "cyclecloud" {
  name                = var.anf_account_name
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_netapp_pool" "cyclecloud" {
  name                = var.anf_pool_name
  location            = var.location
  resource_group_name = module.resource_group.name
  account_name        = azurerm_netapp_account.cyclecloud.name
  service_level       = var.anf_service_level
  size_in_tb          = var.anf_pool_size_tb
  tags                = local.common_tags
}

resource "azurerm_netapp_volume" "cyclecloud" {
  name                = var.anf_volume_name
  location            = var.location
  resource_group_name = module.resource_group.name
  account_name        = azurerm_netapp_account.cyclecloud.name
  pool_name           = azurerm_netapp_pool.cyclecloud.name
  volume_path         = var.anf_volume_path
  service_level       = var.anf_service_level
  subnet_id           = module.network.subnets["anf"].resource_id
  protocols           = ["NFSv4.1"]
  storage_quota_in_gb = var.anf_volume_quota_gb
  security_style      = "unix"
  tags                = local.common_tags
}

data "azurerm_monitor_diagnostic_categories" "bastion" {
  resource_id = azurerm_bastion_host.cyclecloud.id
}

data "azurerm_monitor_diagnostic_categories" "nat_gateway" {
  resource_id = azurerm_nat_gateway.cyclecloud.id
}

data "azurerm_monitor_diagnostic_categories" "locker_blob" {
  resource_id = "${azurerm_storage_account.locker.id}/blobServices/default"
}

data "azurerm_monitor_diagnostic_categories" "bootdiag_blob" {
  resource_id = "${azurerm_storage_account.bootdiag.id}/blobServices/default"
}

data "azurerm_monitor_diagnostic_categories" "anf_account" {
  resource_id = azurerm_netapp_account.cyclecloud.id
}

data "azurerm_monitor_diagnostic_categories" "anf_pool" {
  resource_id = azurerm_netapp_pool.cyclecloud.id
}

data "azurerm_monitor_diagnostic_categories" "anf_volume" {
  resource_id = azurerm_netapp_volume.cyclecloud.id
}

resource "azurerm_monitor_diagnostic_setting" "bastion" {
  name                       = "diag-${var.bastion_name}"
  target_resource_id         = azurerm_bastion_host.cyclecloud.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cyclecloud.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.bastion.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.bastion.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "nat_gateway" {
  name                       = "diag-${var.nat_gateway_name}"
  target_resource_id         = azurerm_nat_gateway.cyclecloud.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cyclecloud.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.nat_gateway.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.nat_gateway.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "locker_blob" {
  name                       = "diag-${var.locker_storage_account_name}-blob"
  target_resource_id         = "${azurerm_storage_account.locker.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cyclecloud.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.locker_blob.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.locker_blob.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "bootdiag_blob" {
  name                       = "diag-${var.bootdiag_storage_account_name}-blob"
  target_resource_id         = "${azurerm_storage_account.bootdiag.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cyclecloud.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.bootdiag_blob.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.bootdiag_blob.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "anf_account" {
  name                       = "diag-${var.anf_account_name}"
  target_resource_id         = azurerm_netapp_account.cyclecloud.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cyclecloud.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.anf_account.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.anf_account.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "anf_pool" {
  name                       = "diag-${var.anf_pool_name}"
  target_resource_id         = azurerm_netapp_pool.cyclecloud.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cyclecloud.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.anf_pool.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.anf_pool.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "anf_volume" {
  name                       = "diag-${var.anf_volume_name}"
  target_resource_id         = azurerm_netapp_volume.cyclecloud.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cyclecloud.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.anf_volume.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.anf_volume.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

module "cyclecloud_vm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.20.0"

  name                = var.cyclecloud_vm_name
  location            = var.location
  resource_group_name = module.resource_group.name
  zone                = var.cyclecloud_vm_zone

  os_type  = "Linux"
  sku_size = var.cyclecloud_vm_size

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  account_credentials = {
    admin_credentials = {
      username                           = var.admin_username
      ssh_keys                           = [tls_private_key.cyclecloud_admin.public_key_openssh]
      generate_admin_password_or_ssh_key = false
    }
    password_authentication_disabled = true
  }

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = toset([azurerm_user_assigned_identity.cyclecloud.id])
  }

  boot_diagnostics                     = true
  boot_diagnostics_storage_account_uri = azurerm_storage_account.bootdiag.primary_blob_endpoint

  diagnostic_settings = {
    vm = {
      name                  = "diag-${var.cyclecloud_vm_name}"
      workspace_resource_id = azurerm_log_analytics_workspace.cyclecloud.id
      metric_categories     = ["AllMetrics"]
    }
  }

  network_interfaces = {
    primary = {
      name = "${var.cyclecloud_vm_name}-nic"
      ip_configurations = {
        primary = {
          name                          = "ipconfig1"
          private_ip_subnet_resource_id = module.network.subnets["cyclecloud"].resource_id
        }
      }
    }
  }

  custom_data      = data.cloudinit_config.cyclecloud.rendered
  enable_telemetry = false
  tags             = local.common_tags

  depends_on = [
    azurerm_netapp_volume.cyclecloud,
    azurerm_role_assignment.cyclecloud_custom
  ]
}
