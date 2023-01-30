resource "azurerm_managed_disk" "vaultstore" {

  count = var.vault_replicas

  zone = count.index + 1


  name                 = "vaultstore-${count.index}"
  resource_group_name  = data.azurerm_resource_group.rg.name
  location             = data.azurerm_resource_group.rg.location
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "8"

  tags = {
    "${var.backup_tag}" = tostring(var.backup)
  }
}

resource "azurerm_management_lock" "vaultstore" {
  count      = var.vault_replicas
  name       = "disk-lock-${count.index}"
  scope      = azurerm_managed_disk.vaultstore[count.index].id
  lock_level = "CanNotDelete"
  notes      = "This is to prevent data loss on vault"
}
