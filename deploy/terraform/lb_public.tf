
resource "azurerm_public_ip" "vault-ext" {
  count = var.public_access ? 1 : 0

  name                = "PublicIPForLB"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "vault-${var.environment}-${var.organization_name}"
}

resource "azurerm_lb" "vaultlb-pub" {
  count = var.public_access ? 1 : 0

  name                = "vaultlb-ext"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard"
  sku_tier            = "Regional"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vault-ext[0].id
  }
}

resource "azurerm_lb_backend_address_pool" "vaultpool-ext" {
  count = var.public_access ? 1 : 0

  loadbalancer_id = azurerm_lb.vaultlb-pub[0].id
  name            = "vaultpool"
}

resource "azurerm_lb_probe" "vaultprobe-ext" {
  count = var.public_access ? 1 : 0

  loadbalancer_id     = azurerm_lb.vaultlb-pub[0].id
  name                = "vault-running-probe"
  port                = 8200
  protocol            = "Https"
  request_path        = "/v1/sys/health"
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "vault-ext" {
  count = var.public_access ? 1 : 0

  loadbalancer_id                = azurerm_lb.vaultlb-pub[0].id
  name                           = "Vault"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 8200
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.vaultprobe-ext[0].id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vaultpool-ext[0].id]
}

output "LBPublicIP" {
  value = try(azurerm_public_ip.vault-ext[0].ip_address, null)
}
