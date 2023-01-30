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

sleep 10
printf "o\nn\np\n1\n\n\nw\n" | sudo fdisk /dev/disk/azure/scsi1/lun0
sleep 5
mkfs.ext4 /dev/disk/azure/scsi1/lun0-part1
sleep 5
mount /dev/disk/azure/scsi1/lun0-part1 /opt/vault/data/
chown -R vault:vault /opt/vault/data

echo "${cacert}" >> /opt/vault/tls/ca.crt
echo "${cakey}" > /opt/vault/tls/ca.key

#generate this server certificate using the CA+key created and injected by terraform
openssl req -newkey rsa:2048 -nodes -keyout /opt/vault/tls/tls.key -subj "/C=CN/ST=GD/L=SZ/O=${organization}/CN=vault.${domain}" -addext "subjectAltName = DNS:vault-${environment}-${organization}.${region}.cloudapp.azure.com" -out /opt/vault/tls/tls.csr
openssl x509 -req -extfile <(printf "subjectAltName=IP:127.0.0.1,DNS:vault.${domain},DNS:v0.${domain},DNS:v1.${domain},DNS:v2.${domain}, DNS:vault-${environment}-${organization}.${region}.cloudapp.azure.com") -days 365 -in /opt/vault/tls/tls.csr -CA /opt/vault/tls/ca.crt -CAkey /opt/vault/tls/ca.key -CAcreateserial -out /opt/vault/tls/tls.crt

#server cert and ca must be concatenated
#https://developer.hashicorp.com/vault/docs/configuration/listener/tcp#tls_cert_file
cat /opt/vault/tls/ca.crt >> /opt/vault/tls/tls.crt
chown -R vault:vault /opt/vault/tls/*

#add the CA to the system store
cp /opt/vault/tls/ca.crt /usr/local/share/ca-certificates/
update-ca-certificates

cat ``> /etc/vault.d/vault.hcl <<EOF
disable_cache           = true
disable_mlock           = true
ui                      = true

listener "tcp" {
   address              = "0.0.0.0:8200"
   tls_client_ca_file   = "/opt/vault/tls/ca.pem"
   tls_cert_file        = "/opt/vault/tls/tls.crt"
   tls_key_file         = "/opt/vault/tls/tls.key"
   tls_disable          = false
}

storage "raft" {

   node_id              = "${hostname}"
   path                 = "/opt/vault/data"
   retry_join {
      leader_api_addr   = "https://v0.${domain}:8200"
   }
   retry_join {
      leader_api_addr   = "https://v1.${domain}:8200"
   }
   retry_join {
      leader_api_addr   = "https://v2.${domain}:8200"
   }
}

seal "azurekeyvault" {
  tenant_id      = "${tenant_id}"
  vault_name     = "${tf_vault_name}"
  key_name       = "unsealkey"
}

cluster_addr            = "https://${hostname}.${domain}:8201"
api_addr                = "https://vault.${domain}"
max_lease_ttl           = "10h"
default_lease_ttl       = "10h"
cluster_name            = "vault"
raw_storage_endpoint    = true
disable_sealwrap        = true
disable_printable_check = true
EOF



#Start vault
systemctl start vault
systemctl enable vault

# export VAULT_ADDR=https://${vault_internal_lb}
# export VAULT_SKIP_VERIFY=1

#init vault
if [ $(hostname) = "v0" ]; then
  VAULT_TOKEN="$(vault operator init | grep "Initial Root Token: " | awk '{print $4}')"
fi

#upload the Vault root token to Azure Keyvault
token=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H Metadata:true | awk -F"[{,\":}]" '{print $6}')

[[ -z "$VAULT_TOKEN" ]] ||  curl -X PUT \
    -s "https://${tf_vault_name}.vault.azure.net/secrets/vaulttoken?api-version=2016-10-01" \
    -H "Authorization: Bearer $${token}" \
    --data-ascii "{'value': '$${VAULT_TOKEN}'}" \
    -H "Content-type: application/json"
echo $${VAULT_TOKEN} >>  ~/.vault-token
vault status

# Hardening https://developer.hashicorp.com/vault/tutorials/operations/production-hardening
#rm /var/log/cloud-init-output.log
chmod 0640 /etc/vault.d/

#enable audit logs
if [ $(hostname) = "v0" ]; then
vault audit enable file file_path=/opt/vault/vault_audit.log
fi

#enable Github Auth method and map a github team to the admin policy

if [ $(hostname) = "v0" ]; then

echo $VAULT_TOKEN
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

# Work with pki secrets engine
path "pki*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}

# Enable and manage the key/value secrets engine at `secret/` path

# List, create, update, and delete key/value secrets
path "secrets/*"
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
fi