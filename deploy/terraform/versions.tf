terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.37.0"
    }
    pkcs12 = {
      source  = "chilicat/pkcs12"
      version = "~>0.0.7"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0.4"
    }
    mysql = {
      source  = "petoju/mysql"
      version = "~>3.0.27"
    }
    local = {
      version = "~> 2.2.3"
    }
  }
  required_version = ">= 1.3"
}
