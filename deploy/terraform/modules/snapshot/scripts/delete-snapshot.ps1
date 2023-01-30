Clear-AzContext -Force
Disable-AzContextAutosave -Scope Process | Out-Null


$AzureContext = (Connect-AzAccount -Identity).context


$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

Get-AzSnapshot -ResourceGroupName ${resource_group} |  
Where-Object TimeCreated -lt (Get-Date).AddDays(-${retention}).ToUniversalTime() |
Where-Object {$_.Tags['createdby'] -eq "backupscript"} |
Remove-AzSnapshot 