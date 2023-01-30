terraform {
  # Resource_group_name and storage_account_name will come from  backend config variables:

  backend "azurerm" {
    container_name = "tfstate"
    key            = "infra-vault.terraform.tfstate"
  }
}
