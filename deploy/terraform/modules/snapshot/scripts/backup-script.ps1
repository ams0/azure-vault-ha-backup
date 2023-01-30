Clear-AzContext -Force
Disable-AzContextAutosave -Scope Process | Out-Null


$AzureContext = (Connect-AzAccount -Identity).context


$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription `
    -DefaultProfile $AzureContext

# Get disk with snapshot tag

$tagResList = Get-AzResource -ResourceGroupName "${resource_group}" -TagName "${tag}" -TagValue "true" | foreach {

Get-AzResource -ResourceId $_.resourceid

}

foreach($tagRes in $tagResList) {

  if($tagRes.ResourceId -match "Microsoft.Compute/disks")

 {
 $diskInfo = Get-AzDisk -ResourceGroupName $tagRes.ResourceId.Split("//")[4] -Name $tagRes.ResourceId.Split("//")[8]

  #Set local variables

    $location = $diskInfo.Location
    $resourceGroupName = $diskInfo.ResourceGroupName
    $timestamp = Get-Date -f MM-dd-yyyy_HH_mm_ss
    $snapshotName = $diskInfo.Name + $timestamp
    Write-Output $snapshotName
    $snapshot = New-AzSnapshotConfig -SourceUri $diskInfo.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy

    $snapshotConfig = New-AzSnapshotConfig -Incremental -SourceResourceId $diskInfo.Id -Location $location -CreateOption Copy 

    New-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName -Snapshot $snapshotconfig     
    $tag = @{createdby="backupscript"}

    Set-AzResource -ResourceGroupName $resourceGroupName -Name $snapshotName -ResourceType "Microsoft.Compute/snapshots" -Tag $tag -Force

 }
}