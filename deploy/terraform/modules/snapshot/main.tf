data "azurerm_resource_group" "rg" {
  name = var.resource_group
}

data "azurerm_subscription" "primary" {
}
resource "azurerm_role_assignment" "reader" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Reader"
  principal_id         = azurerm_automation_account.vault-disk-backup.identity[0].principal_id
}

resource "azurerm_role_assignment" "snapshottter" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Disk Snapshot Contributor"
  principal_id         = azurerm_automation_account.vault-disk-backup.identity[0].principal_id
}

resource "azurerm_automation_account" "vault-disk-backup" {
  name                = "vault-disk-backup"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_automation_schedule" "schedule" {
  name                    = "${var.frequency}-schedule"
  resource_group_name     = data.azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.vault-disk-backup.name
  frequency               = var.frequency
  interval                = 1
  description             = "This is an example schedule"
}

resource "azurerm_automation_job_schedule" "snapshot" {
  resource_group_name     = data.azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.vault-disk-backup.name
  schedule_name           = azurerm_automation_schedule.schedule.name
  runbook_name            = azurerm_automation_runbook.vault-disk-backup.name

  parameters = {
    resourcegroup = "vault"
    tag           = "Snapshot"
  }
}

resource "azurerm_automation_runbook" "vault-disk-backup" {
  name                    = "vault-disk-backup"
  location                = data.azurerm_resource_group.rg.location
  resource_group_name     = data.azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.vault-disk-backup.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "This is an example runbook"
  runbook_type            = "PowerShell"

  content = templatefile("${path.module}/scripts/backup-script.ps1", { resource_group = "${data.azurerm_resource_group.rg.name}", tag = "${var.tag}" })

  #this needs to be here because of this bug https://github.com/hashicorp/terraform-provider-azurerm/issues/4851
  publish_content_link {
    uri = "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/c4935ffb69246a6058eb24f54640f53f69d3ac9f/101-automation-runbook-getvms/Runbooks/Get-AzureVMTutorial.ps1"
  }
}


resource "azurerm_automation_runbook" "vault-disk-snapshot-deleter" {
  name                    = "vault-disk-snapshot-deleter"
  location                = data.azurerm_resource_group.rg.location
  resource_group_name     = data.azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.vault-disk-backup.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "This is an example runbook"
  runbook_type            = "PowerShell"

  content = templatefile("${path.module}/scripts/delete-snapshot.ps1", { resource_group = "${data.azurerm_resource_group.rg.name}", retention = "${var.retention}" })

  #this needs to be here because of this bug https://github.com/hashicorp/terraform-provider-azurerm/issues/4851
  publish_content_link {
    uri = "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/c4935ffb69246a6058eb24f54640f53f69d3ac9f/101-automation-runbook-getvms/Runbooks/Get-AzureVMTutorial.ps1"
  }
}
