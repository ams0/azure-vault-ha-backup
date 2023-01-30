#Private DNS zone for the VMSS instances to find each other and the vault loadbalanced address via DNS

resource "azurerm_private_dns_zone" "vault" {
  name                = "${var.environment}.${var.ca_common_name}"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dnslink" {
  name                  = "vaultdnslink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "vault-lb" {
  name                = "vault"
  zone_name           = azurerm_private_dns_zone.vault.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_lb.vaultlb.frontend_ip_configuration[0].private_ip_address]
}
