######################################## variables ##########################################
$subid = #Subscription ID for the subscription containing the VM deployed to update
$rgName = #Resource Group containing the VM deployed for upgrading
$vmName = #Name of the VM to be updates
$skuName = #Type fo SKU desired for storage account e.g "Standard_LRS" 
$imageContainerName = #Storage Container Name within the Storage Account e.g "images"
$SnapshotName = #Name to be givent to the temporary snapshot created e.g. "temporary-snap"
#############################################################################################

################################ Login As Automation Account ################################
try
{
	$Conn = Get-AutomationConnection -Name AzureRunAsConnection
	Login-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID `
	-ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
	Write-Output "Successfully connected as Automation Account"
}
catch
{
    Write-Output "Error connecting as Automation Account"
    Write-Output $_.Exception.Message
}

$null = Set-AzureRMContext -SubscriptionId $subid
$validLocations = Get-AzureRMLocation | where-object Providers -Contains Microsoft.Storage |Sort-Object Location | ForEach-Object {$_.Location}
#############################################################################################

############################## Stop and Mark VM as Generalised ##############################
try 
{
    Stop-AzureRmVM -ResourceGroupName $rgName -Name $vmName -Force    
}
catch 
{
    Write-Output "Error Stopping VM"
    Write-Output $_.Exception.Message
}

try 
{
    Set-AzureRmVm -ResourceGroupName $rgName -Name $vmName -Generalized     
}
catch 
{
    Write-Output "Error Generalizing VM"
    Write-Output $_.Exception.Message
}

#############################################################################################

################################### Remove Previous Images ##################################
$images = Get-AzureRMResource -ResourceType Microsoft.Compute/images |  ForEach-Object {$_.Name}
foreach ($currentimage in $images)
{
    Remove-AzureRmImage -ResourceGroupName $rgName -ImageName $currentimage -force
}
#############################################################################################

######################## Create a Storage Container in all Locations ########################
foreach ($currentLocation in $validLocations)
{
    $storageAccName = "tmplt" + $currentLocation

    Write-Output "Creating Destination Storage Account: $storageAccName"
    # Create Destination Storage Account (skip if exists)
    if ($null -eq (Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name ${storageAccName} -ErrorAction SilentlyContinue))
    {
        try
        {
            New-AzureRmStorageAccount -ResourceGroupName $rgName -AccountName $storageAccName -Location $currentLocation -Type $skuName -EnableHttpsTrafficOnly 1 -ErrorAction Continue
            $targetStorageContext = (Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $storageAccName).Context
            New-AzureStorageContainer -Name $imageContainerName -Context $targetStorageContext -Permission Container
        }
        catch
        {
            Write-Output $_.Exception.Message
        }
    } 
    else 
    {
        Write-Output " SA $storageAccName Already Exists!"
    }

}
#############################################################################################

########################## Snapshot the OS Disk of the template VM ##########################
$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
$disk = Get-AzureRmDisk -ResourceGroupName $rgName -DiskName $vm.StorageProfile.OsDisk.Name
$snapshot = New-AzureRmSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location ukwest
New-AzureRmSnapshot -ResourceGroupName $rgName -Snapshot $snapshot -SnapshotName $SnapshotName
#############################################################################################

########################## Copy the Snapshot to SAs in all Regions ##########################
Write-Output "Starting Snapshot copy to other regions"

$snapSasUrl = Grant-AzureRmSnapshotAccess -ResourceGroupName $rgName -SnapshotName $snapshotName -DurationInSecond 7200 -Access Read

foreach ($currentLocation in $validLocations)
{
    try
    {
        $storageAccName = "tmplt" + $currentLocation
        $imageBlobName = "tmpltsnap" + $currentLocation

        $targetStorageContext = (Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $storageAccName).Context
        
        Start-AzureStorageBlobCopy -AbsoluteUri $snapSasUrl.AccessSAS -DestContainer $imageContainerName -DestContext $targetStorageContext -DestBlob $imageBlobName -Force 
        Write-Output "started copying $imageBlobName to $currentLocation"
    }
    catch
    {
        Write-Output $_.Exception.Message
    }
}
#############################################################################################
# Due to Runbook execute time limitations, this Runbook will terminate, allowing time for the 
# Copy process, which will be checked in "5. Create all Images and Cleanup"
#############################################################################################