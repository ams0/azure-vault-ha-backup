# This generates a CA+key, Vault certificates+key and the SSL cert for the application gateway

resource "tls_private_key" "ca" {
  algorithm   = var.private_key_algorithm
  ecdsa_curve = var.private_key_ecdsa_curve
  rsa_bits    = var.private_key_rsa_bits
}

resource "tls_self_signed_cert" "ca" {
  is_ca_certificate     = true
  private_key_pem       = tls_private_key.ca.private_key_pem
  validity_period_hours = var.validity_period_hours
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    #the below is VERY important, spent a lot of time figuring it out!
    "cert_signing",
  ]

  subject {
    common_name  = var.ca_common_name
    organization = var.organization_name
  }
}
