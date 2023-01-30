# Set var.backup = true to enable VMSS daily backups
resource "azurerm_recovery_services_vault" "vault" {

  count = var.backup == true ? 1 : 0

  name                = "vault-recovery-vault"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  soft_delete_enabled = true
}

resource "azurerm_backup_policy_vm" "vault-vm-backup" {
  count = var.backup == true ? 1 : 0

  name                = "vault-recovery-vault-policy"
  resource_group_name = data.azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vault[0].name

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 10
  }

  retention_weekly {
    count    = 42
    weekdays = ["Sunday", "Wednesday", "Friday", "Saturday"]
  }

  retention_monthly {
    count    = 7
    weekdays = ["Sunday", "Wednesday"]
    weeks    = ["First", "Last"]
  }

  retention_yearly {
    count    = 77
    weekdays = ["Sunday"]
    weeks    = ["Last"]
    months   = ["January"]
  }
}
