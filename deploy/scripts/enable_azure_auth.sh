## This snippet nables vault azure auth, it's here just for reference
#https://github.com/hashicorp/vault-guides/blob/master/operations/azure-keyvault-unseal/setup.tpl
# vault auth enable azure
# vault write auth/azure/config \
#   tenant_id="${tenant_id}" \
#   resource="https://management.azure.com/" \
#   client_id="${client_id}" \
#   client_secret="${client_secret}"
# vault write auth/azure/role/dev-role \
#   policies="default" \
#   bound_subscription_ids="${subscription_id}" \
#   bound_resource_groups="${resource_group_name}"
# # create a vault login token for the current virtual machine identity (as
# # returned by the azure instance metadata service).
# # NB use the returned token to login into vault using `vault login`.
# # see https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-use-vm-token
# # see https://docs.microsoft.com/en-us/azure/virtual-machines/linux/instance-metadata-service
# vault write auth/azure/login \
#   role="dev-role" \
#   jwt="$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -H Metadata:true -s | jq -r .access_token)" \
#   subscription_id="${subscription_id}" \
#   resource_group_name="${resource_group_name}" \
#   vm_name="${vm_name}"

vault auth enable github
vault write auth/github/config organization=sede-x
vault write auth/github/map/teams/dsx-system-team value=root
