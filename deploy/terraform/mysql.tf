resource "random_password" "mysqlpw" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "dbadminpw" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_private_dns_zone" "vaultdb" {
  name                = "vault.mysql.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dblink" {
  name                  = "dblink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.vaultdb.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

resource "azurerm_mysql_flexible_server" "vaultdb" {
  name                   = "vaultdb${var.environment}"
  zone                   = "3"
  location               = data.azurerm_resource_group.rg.location
  resource_group_name    = data.azurerm_resource_group.rg.name
  administrator_login    = var.dbadminusername
  administrator_password = random_password.dbadminpw.result
  backup_retention_days  = 7
  version                = "8.0.21"
  delegated_subnet_id    = data.azurerm_subnet.db_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.vaultdb.id
  sku_name               = "B_Standard_B1ms"
  storage {
    size_gb = "20"
  }
  depends_on = [azurerm_private_dns_zone_virtual_network_link.dnslink, azurerm_private_dns_zone_virtual_network_link.dblink]
}

resource "azurerm_mysql_flexible_database" "vault" {
  name                = var.vaultdbname
  resource_group_name = data.azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.vaultdb.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

#the password for the vault user
resource "random_password" "vaultdbpw" {
  length      = 20
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

# Below is not working because the flexible servcer is vnet-constrained, leaving it here for reference if moving to public-access server

# data "http" "myip" {
#   url = "http://ifconfig.me/ip"
# }
# resource "azurerm_mysql_firewall_rule" "mysql_firewall_clientip" {
#   name                = "ClientIpAddress"
#   resource_group_name = data.azurerm_resource_group.rg.name
#   server_name         = azurerm_mysql_flexible_server.vaultdb.name
#   start_ip_address    = chomp(data.http.myip.body)
#   end_ip_address      = chomp(data.http.myip.body)
# }

# provider "mysql" {
#   endpoint = "${azurerm_mysql_flexible_server.vaultdb.name}.mysql.database.azure.com:3306"
#   username = "${var.dbadminusername}@${azurerm_mysql_flexible_server.vaultdb.name}"
#   password = random_password.dbadminpw.result
#   tls      = true
# }

# resource "mysql_user" "vaultuser" {
#   user               = var.vaultdbdminusername
#   host               = "%"
#   plaintext_password = random_password.vaultdbpw.result
# }

# resource "mysql_grant" "useraccess" {
#   user       = mysql_user.vaultuser.user
#   host       = mysql_user.vaultuser.host
#   database   = var.vaultdbname
#   privileges = ["*"]
# }

resource "azurerm_management_lock" "mysqllock" {
  name       = "mysql-lock"
  scope      = azurerm_mysql_flexible_server.vaultdb.id
  lock_level = "CanNotDelete"
  notes      = "Locked because it's needed by a Vault"
}
