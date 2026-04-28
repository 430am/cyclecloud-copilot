locals {
  common_tags = merge(var.tags, {
    component = "cyclecloud-landing-zone"
  })

  names = {
    vnet                      = "${var.name_prefix}-vnet"
    cyclecloud_subnet         = "snet-cyclecloud"
    cluster_subnet            = "snet-cluster"
    private_endpoint_sub      = "snet-private-endpoints"
    bastion_subnet            = "AzureBastionSubnet"
    anf_subnet                = "snet-anf"
    keyvault_pe               = "${var.name_prefix}-pep-kv"
    private_dns_zone_kv       = "privatelink.vaultcore.azure.net"
    private_dns_zone_blob     = "privatelink.blob.core.windows.net"
    locker_pe                 = "${var.name_prefix}-pep-locker"
    bootdiag_pe               = "${var.name_prefix}-pep-bootdiag"
    private_dns_zone_monitor  = "privatelink.monitor.azure.com"
    private_dns_zone_oms      = "privatelink.oms.opinsights.azure.com"
    private_dns_zone_ods      = "privatelink.ods.opinsights.azure.com"
    private_dns_zone_agentsvc = "privatelink.agentsvc.azure-automation.net"
    monitor_pe                = "${var.name_prefix}-pep-monitor"
  }
}
