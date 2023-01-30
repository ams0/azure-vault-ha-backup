module "snapshot" {
  count          = var.backup ? 1 : 0
  source         = "./modules/snapshot"
  resource_group = data.azurerm_resource_group.rg.name
  tag            = var.backup_tag
  frequency      = var.frequency
}
