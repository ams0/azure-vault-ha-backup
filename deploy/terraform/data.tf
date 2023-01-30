# These are resources that already exist, usually created and owned by some other process:

data "azurerm_client_config" "current" {}
data "azurerm_resource_group" "rg" {
  name = var.resource_group
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnetrg
}

data "azurerm_subnet" "vault" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.vnetrg
}


data "azurerm_subnet" "db_subnet" {
  name                 = var.db_subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.vnetrg
}
