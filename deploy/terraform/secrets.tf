resource "azurerm_key_vault_secret" "vaultca" {
  depends_on = [
    azurerm_key_vault_access_policy.tf_policy
  ]
  name         = "vaultca"
  value        = tls_self_signed_cert.ca.cert_pem
  key_vault_id = azurerm_key_vault.kv_vault.id
}

resource "azurerm_key_vault_secret" "vaultcakey" {
  depends_on = [
    azurerm_key_vault_access_policy.tf_policy
  ]
  name         = "vaultcakey"
  value        = tls_private_key.ca.private_key_pem
  key_vault_id = azurerm_key_vault.kv_vault.id
}

resource "azurerm_key_vault_key" "unseal" {
  depends_on = [
    azurerm_key_vault_access_policy.tf_policy
  ]
  name         = var.key_name
  key_vault_id = azurerm_key_vault.kv_vault.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}
