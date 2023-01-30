resource "azurerm_user_assigned_identity" "vault-mi" {
  location            = data.azurerm_resource_group.rg.location
  name                = "${var.app_name}-${var.environment}-mi"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "random_integer" "vault" {
  min = 1000
  max = 9999
}

resource "azurerm_key_vault" "kv_vault" {
  name                            = "${var.kv_vault_name}${random_integer.vault.result}${var.environment}"
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  location                        = data.azurerm_resource_group.rg.location
  purge_protection_enabled        = false
  resource_group_name             = data.azurerm_resource_group.rg.name
  sku_name                        = "standard"
  soft_delete_retention_days      = 90
  tenant_id                       = var.tenant_id

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.ip_rules
    virtual_network_subnet_ids = [data.azurerm_subnet.vault.id]
  }
}

resource "azurerm_key_vault_access_policy" "tf_policy" {
  key_vault_id = azurerm_key_vault.kv_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
    "Update",
    "Purge",
    "Recover",
  ]

  secret_permissions = [
    "Set",
    "Get",
    "Delete",
    "Purge",
    "Recover"
  ]
}

resource "azurerm_key_vault_access_policy" "kv_vaultmi_access_policy" {
  key_vault_id = azurerm_key_vault.kv_vault.id
  object_id    = azurerm_user_assigned_identity.vault-mi.principal_id
  certificate_permissions = [

  ]
  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey",
  ]
  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover",
  ]
  tenant_id = var.tenant_id
}
