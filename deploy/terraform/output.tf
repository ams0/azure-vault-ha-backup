data "local_file" "text" {
  filename = "../files/vault.txt"
}

data "azurerm_key_vault_secret" "vaulttoken" {
  name         = "vaulttoken"
  key_vault_id = azurerm_key_vault.kv_vault.id
}

output "ca" {
  value     = tls_self_signed_cert.ca.cert_pem
}
output "text" {
  value = replace(data.local_file.text.content, "kv_name", azurerm_key_vault.kv_vault.name)
}

