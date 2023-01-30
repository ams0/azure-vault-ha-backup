resource "azurerm_lb" "vaultlb" {
  name                = "vaultlb"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard"
  sku_tier            = "Regional"

  frontend_ip_configuration {
    name      = "InternalIP"
    subnet_id = data.azurerm_subnet.vault.id
  }
}

resource "azurerm_lb_backend_address_pool" "vaultpool" {
  loadbalancer_id = azurerm_lb.vaultlb.id
  name            = "vaultpool"
}

resource "azurerm_lb_probe" "vaultprobe" {
  loadbalancer_id     = azurerm_lb.vaultlb.id
  name                = "vault-running-probe"
  port                = 8200
  protocol            = "Https"
  request_path        = "/v1/sys/health"
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "vault" {
  loadbalancer_id                = azurerm_lb.vaultlb.id
  name                           = "Vault"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 8200
  frontend_ip_configuration_name = "InternalIP"
  probe_id                       = azurerm_lb_probe.vaultprobe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vaultpool.id]
}
