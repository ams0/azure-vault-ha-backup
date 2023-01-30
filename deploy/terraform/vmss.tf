# Create Security Group to access vault

resource "azurerm_network_security_group" "vault-vm-nsg" {
  name                = "${var.app_name}-${var.environment}-vault-vm-nsg"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  security_rule {
    name                       = "allow-ssh"
    description                = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-vault"
    description                = "allow-vault"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8200"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

# Vault VMSS

resource "azurerm_linux_virtual_machine_scale_set" "vault" {
  name                = "vault-vmss-${var.environment}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard_B1s"
  instances           = var.vault_replicas
  admin_username      = "adminuser"
  #https://github.com/hashicorp/terraform/issues/2104
  custom_data = base64encode(templatefile("../scripts/install_vault.sh", { sqlca = file("../files/mysql-ca.pem"), adminpw = random_password.dbadminpw.result, address = azurerm_mysql_flexible_server.vaultdb.fqdn, database = var.vaultdbname, username = var.vaultdbdminusername, password = random_password.vaultdbpw.result, cacert = "${tls_self_signed_cert.ca.cert_pem}", cakey = "${tls_private_key.ca.private_key_pem}", lb_name = "vault.${var.environment}.${var.ca_common_name}", tf_vault_name = azurerm_key_vault.kv_vault.name, user = var.vmss_username, tenant_id = data.azurerm_client_config.current.tenant_id, github_org = var.github_org, github_admin_team = var.github_admin_team, vault_internal_lb = azurerm_private_dns_a_record.vault-lb.fqdn }))

  zones        = [1, 2, 3]
  zone_balance = true

  admin_ssh_key {
    username   = var.vmss_username
    public_key = var.first_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vault-mi.id]
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name                      = "vaultnic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.vault-vm-nsg.id

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = data.azurerm_subnet.vault.id
      load_balancer_backend_address_pool_ids = compact([azurerm_lb_backend_address_pool.vaultpool.id, try(azurerm_lb_backend_address_pool.vaultpool-ext[0].id, null)])
      #remove below for production
      dynamic "public_ip_address" {
        for_each = var.public_access == true ? [1] : []
        content {
          name                = "pubip"
          public_ip_prefix_id = var.public_ip_prefix_id
        }
      }
    }
  }
}
