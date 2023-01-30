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

resource "azurerm_network_interface" "vaultnic" {
  count = var.vault_replicas

  name                = "vaultnic-${count.index}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vault.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "vaultnsg" {
  count                     = var.vault_replicas
  network_interface_id      = azurerm_network_interface.vaultnic[count.index].id
  network_security_group_id = azurerm_network_security_group.vault-vm-nsg.id
}

resource "azurerm_linux_virtual_machine" "vault" {
  count = var.vault_replicas

  name                = "v${count.index}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = var.vm_username
  network_interface_ids = [
    azurerm_network_interface.vaultnic[count.index].id
  ]
  zone = count.index + 1

  custom_data = base64encode(templatefile("../scripts/install_vault.sh", { organization = "${var.organization_name}", region = "${data.azurerm_resource_group.rg.location}", environment = "${var.environment}", hostname = "v${count.index}", cacert = "${tls_self_signed_cert.ca.cert_pem}", cakey = "${tls_private_key.ca.private_key_pem}", domain = "${var.environment}.${var.ca_common_name}", lb_name = "vault.${var.environment}.${var.ca_common_name}", tf_vault_name = azurerm_key_vault.kv_vault.name, user = var.vm_username, tenant_id = data.azurerm_client_config.current.tenant_id, github_org = var.github_org, github_admin_team = var.github_admin_team, vault_internal_lb = azurerm_private_dns_a_record.vault-lb.fqdn }))


  admin_ssh_key {
    username   = var.vm_username
    public_key = var.first_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.vault-mi.id
    ]
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "vaultdisk" {
  count              = var.vault_replicas
  managed_disk_id    = azurerm_managed_disk.vaultstore[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vault[count.index].id
  lun                = "0"
  caching            = "ReadWrite"
}

resource "azurerm_network_interface_backend_address_pool_association" "backendvault-internal" {
  count                   = var.vault_replicas
  network_interface_id    = azurerm_network_interface.vaultnic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.vaultpool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "backendvault-external" {
  count                   = var.vault_replicas
  network_interface_id    = azurerm_network_interface.vaultnic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.vaultpool-ext[0].id
}
