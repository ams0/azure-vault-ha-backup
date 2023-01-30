#!/bin/bash

set -x

ip_address="$(ip addr show eth0 | perl -n -e'/ inet (\d+(\.\d+)+)/ && print $1')"
export DEBIAN_FRONTEND=noninteractive
#https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install
apt update > /dev/null&& apt upgrade -q0 -y > /dev/null && apt -y -qq install gpg > /dev/null
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor |  tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
apt update > /dev/null && apt -y -qq install vault jq > /dev/null

echo "${cacert}" >> /opt/vault/tls/ca.crt
echo "${cakey}" > /opt/vault/tls/ca.key
echo "${sqlca}" > /opt/vault/tls/mysql-ca.pem

#generate this server certificate using the CA+key created and injected by terraform
openssl req -newkey rsa:2048 -nodes -keyout /opt/vault/tls/tls.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=vault.dev.vault" -out /opt/vault/tls/tls.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:127.0.0.1,DNS:vault.dev.vault") -days 365 -in /opt/vault/tls/tls.csr -CA /opt/vault/tls/ca.crt -CAkey /opt/vault/tls/ca.key -CAcreateserial -out /opt/vault/tls/tls.crt

#server cert and ca must be concatenated
#https://developer.hashicorp.com/vault/docs/configuration/listener/tcp#tls_cert_file
cat /opt/vault/tls/ca.crt >> /opt/vault/tls/tls.crt
chown -R vault:vault /opt/vault/tls/*

#add the CA to the system store
cp /opt/vault/tls/ca.crt /usr/local/share/ca-certificates/
update-ca-certificates


#initialize the database if it's the first time
apt-get -y -qq install mysql-client > /dev/null
#the create user command may fail if the user exists already, please ignore
mysql -h ${address} -u dbadmin -p"${adminpw}" -e "CREATE USER '${username}'@'$ip_address' IDENTIFIED BY '${password}'"
mysql -h ${address} -u dbadmin -p"${adminpw}" -e "GRANT ALL PRIVILEGES ON vaultdb.* TO '${username}'@'$ip_address'"

cat ``> /etc/vault.d/vault.hcl <<EOF
ui = true

#mlock = true
disable_mlock = true
api_addr = "https://${lb_name}"
cluster_addr = "https://${lb_name}:8201"

storage "mysql" {
  ha_enabled = "true"
  address    = "${address}"
  username   = "${username}"
  password   = "${password}"
  database   = "${database}"
  table      = "vault"
  lock_table = "vault_lock"
  plaintext_connection_allowed = "false"
  tls_ca_file = "/opt/vault/tls/mysql-ca.pem"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  tls_cert_file  = "/opt/vault/tls/tls.crt"
  tls_key_file   = "/opt/vault/tls/tls.key"
  telemetry {
    unauthenticated_metrics_access = true
  }
}

telemetry {
   disable_hostname = true
   prometheus_retention_time = "24h"
}

seal "azurekeyvault" {
  tenant_id      = "${tenant_id}"
  vault_name     = "${tf_vault_name}"
  key_name       = "unsealkey"
}
EOF

#Start vault
systemctl start vault
systemctl enable vault

export VAULT_ADDR=https://${vault_internal_lb}
export VAULT_SKIP_VERIFY=1

#init vault
VAULT_TOKEN="$(vault operator init | grep "Initial Root Token: " | awk '{print $4}')"

#upload the Vault root token to Azure Keyvault
token=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H Metadata:true | awk -F"[{,\":}]" '{print $6}')

[[ -z "$VAULT_TOKEN" ]] ||  curl -X PUT \
    -s "https://${tf_vault_name}.vault.azure.net/secrets/vaulttoken?api-version=2016-10-01" \
    -H "Authorization: Bearer $${token}" \
    --data-ascii "{'value': '$${VAULT_TOKEN}'}" \
    -H "Content-type: application/json"

vault status

# Hardening https://developer.hashicorp.com/vault/tutorials/operations/production-hardening
#rm /var/log/cloud-init-output.log
chmod 0640 /etc/vault.d/

#enable audit logs
vault audit enable file file_path=/var/log/vault_audit.log

#enable Github Auth method and map a github team to the admin policy


tee admin-policy.hcl <<EOF
# Read system health check
path "sys/health"
{
  capabilities = ["read", "sudo"]
}

# Create and manage ACL policies broadly across Vault

# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# Create and manage ACL policies
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Enable and manage authentication methods broadly across Vault

# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = ["create", "update", "delete", "sudo"]
}

# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}

# Enable and manage the key/value secrets engine at `secret/` path

# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secrets engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}
EOF
vault policy write admin admin-policy.hcl
vault auth enable github
vault write auth/github/config organization=${github_org}
vault write auth/github/map/teams/${github_admin_team} value=admin
