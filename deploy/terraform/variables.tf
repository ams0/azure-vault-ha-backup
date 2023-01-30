variable "resource_group" {
  description = "The existing resource group to hold all resources created by this module"
  default     = ""
}
variable "tenant_id" {
  description = "the tenant id"
  default     = ""
}

variable "kv_vault_name" {
  description = "A name for the Keyvault created by this module to hold the Vault files and keys"
  default     = ""
}

variable "environment" {
  description = "The environment, can be dev/uat/prod"
  default     = ""
}
variable "app_name" {
  description = "the app name, in this case, vault"
  default     = ""
}

variable "ip_rules" {
  description = "The IP addresses or CIDR to be allowed into the keyvault"
  type        = list(string)
}

variable "organization_name" {
  description = "The name of the org to sign the CA cert"
  default     = ""
}

variable "ca_common_name" {
  description = "the CA common name"
  default     = ""
}
variable "private_key_algorithm" {
  description = "The name of the algorithm to use for private keys. Must be one of: RSA or ECDSA."
  default     = "RSA"
}

variable "private_key_rsa_bits" {
  description = "The size of the generated RSA key in bits. Should only be used if var.private_key_algorithm is RSA."
  default     = 2048
}

variable "private_key_ecdsa_curve" {
  description = "The name of the elliptic curve to use. Should only be used if var.private_key_algorithm is ECDSA. Must be one of P224, P256, P384 or P521."
  default     = "P256"
}

variable "validity_period_hours" {
  description = "The number of hours after initial issuing that the certificate will become invalid."
  default     = 8760
}

variable "ca_allowed_uses" {
  description = "List of keywords from RFC5280 describing a use that is permitted for the CA certificate. For more info and the list of keywords, see https://www.terraform.io/docs/providers/tls/r/self_signed_cert.html#allowed_uses."

  default = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}
variable "key_name" {
  description = "The key name with the auto unseal key"
  default     = "unsealkey"
}

variable "vnetrg" {
  description = "The resource group that holds the VNET"
}
variable "vnet_name" {
  description = "The VNET name"
}

variable "subnet_name" {
  description = "The subnet for the vault, must have the Microsoft.DBforMySQL/flexibleServers delegation"
}

variable "db_subnet_name" {
  description = "The subnet for the vault, must have the Microsoft.DBforMySQL/flexibleServers delegation"
}

variable "vmss_username" {
  description = "VMSS username"
}

variable "dbadminusername" {
  description = "DB username"
}
variable "vaultdbname" {
  description = "Name for the Vault database"
}
variable "vaultdbdminusername" {
  description = "Username for the vault user on the vault database"
}
variable "vault_replicas" {
  description = "VMSS replicas"
}

variable "first_public_key" {
  description = "The ssh key to access the VMSS"
}

variable "public_ip_prefix_id" {
  description = "A public IP prefix to access the VMSS"
}

variable "public_access" {
  description = "Whether to attach a public IP to each vm"
}

variable "backup" {
  description = "Switch for backup"
}
variable "github_org" {
  description = "The Github org allowed to login in Vault"
}

variable "github_admin_team" {
  description = "The name of the Github team mapped to admin policy in Vault"
}
