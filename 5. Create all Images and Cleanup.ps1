######################################## variables ##########################################
$subid = #Subsctiption ID in which you want to deploy the VM
$subName = #Subsctiption Name in which you want to deploy the VM
$vmName = #Name of the VM Tamplate Created in "1. Build New Template to Update"
$rgName = #Name of the Resource Group the VM Tamplate Resides in, in "1. Build New Template to Update"
$vnetName = #Name of the vnet Created in "1. Build New Template to Update"
$ipName = #Name of the IP Created in "1. Build New Template to Update"
$nsgName = ##Name of the NSG Tamplate Created in "1. Build New Template to Update"
$imageContainerName = #Storage Container Name within the Storage Account created in "4. Snapshot and Move to SAs" e.g "images"
$SnapshotName = #Name given to the snapshot created in "4. Snapshot and Move to SAs" e.g. "temporary-snap"
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
}

$null = Set-AzureRMContext -SubscriptionId $subid
$validLocations = Get-AzureRMLocation | where-object Providers -Contains Microsoft.Storage |Sort-Object Location | ForEach-Object {$_.Location}
#############################################################################################

################################### Check Status of Copy ####################################
$completedArray = @()
$complete = "0"

while ($complete -eq 0)
{
    foreach ($currentLocation in $validLocations)
    {
		$storageAccName = "tmplt" + $currentLocation
		$imageBlobName = "tmpltsnap" + $currentLocation
		$targetStorageContext = (Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $storageAccName).Context
        $CopyState = Get-AzureStorageContainer -Context $targetStorageContext -Name $imageContainerName | Get-AzureStorageBlobCopyState -Blob $imageBlobName
        $Message = $imageBlobName + " " + $CopyState.Status + " {0:N2}%" -f (($CopyState.BytesCopied/$CopyState.TotalBytes)*100) 
        Write-Output $Message
        
        Write-Output "$CopyState.Status"

        if ($CopyState.Status -eq "Success")
        {
            $completedArray += "1"
        }
        elseif ($CopyState.Status -eq "Failed") 
        {
            $completedArray += "1"
        }
        else
        {
            $completedArray += "0"
        }
    }

    Write-Output $completedArray

    if ($completedArray.Contains("0"))
    {
        $completedArray = @()
    }
    else 
    {	
        $complete = "1"
	}
	
	Start-Sleep -Seconds 300
}
#############################################################################################

################################ Create Snapshot of each vhd ################################
foreach ($currentLocation in $validLocations)
{
    try
    {
        $storageAccName = "tmplt" + $currentLocation
        $imageBlobName = "tmpltsnap" + $currentLocation

        $targetStorageContext = (Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $storageAccName).Context

        # Get the full URI to the blob
        $osDiskVhdUri = ($targetStorageContext.BlobEndPoint + $imageContainerName + "/" + $imageBlobName)
        Write-Output $osDiskVhdUri
        # Build up the snapshot configuration, using the target storage account's resource ID
        $snapshotConfig = New-AzureRmSnapshotConfig -AccountType Standard_LRS `
                                                    -OsType Windows `
                                                    -Location $currentLocation `
                                                    -CreateOption Import `
                                                    -SourceUri $osDiskVhdUri `

        # Create the new snapshot in the target region
        $newSnapshotName = "snap" + $currentlocation
        New-AzureRmSnapshot -ResourceGroupName $rgName -SnapshotName $newSnapshotName -Snapshot $snapshotConfig
        write-output "Creating Snapshot $newSnapshotName"
    }
    catch
    {
        Write-Output $_.Exception.Message
    }
}
#############################################################################################

############################### Create Image of Snapshots ###################################
foreach ($currentLocation in $validLocations)
{
    
    try 
    {
        $newSnapshotName = "snap" + $currentLocation
        $imageName = "tmpltimage" + $currentLocation
        $snapshot = Get-AzureRmSnapshot -ResourceGroupName $rgName -SnapshotName $newSnapshotName
        $imageConfig = New-AzureRmImageConfig -Location $currentlocation
        $imageConfig = Set-AzureRmImageOsDisk -Image $imageConfig -OsState Generalized -OsType Windows -SnapshotId $snapshot.Id
        New-AzureRmImage -ImageName $imageName -ResourceGroupName $rgName -Image $imageConfig  
    }
    catch 
    {
        Write-output $_.Exception.Message
    }

}
#############################################################################################

######################################## Remove SAs #########################################
foreach ($currentLocation in $validLocations)
{
    $storageAccName = "tmplt" + $currentLocation

	if ($null -ne (Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $storageAccName -ErrorAction SilentlyContinue))
	{
        try
        {
    	    write-output "Removing Storage Account: $storageAccName"
            Remove-AzureRmStorageAccount -ResourceGroupName $rgName -Name $storageAccName -Force -ErrorAction SilentlyContinue
        }
        catch
        {
            Write-output $_.Exception.Message
        }
    }
    else 
    {
        write-output "Storage Account: $storageAccName Not Found"
    }
}
#############################################################################################

################################### Remove Snapshots #########################################
foreach ($currentLocation in $validLocations)
{
    
    try 
    {
        $tempSnapshotName = "snap" + $currentLocation
        Remove-AzureRmSnapshot -ResourceGroupName $rgName -SnapshotName $tempSnapshotName -Force
    }
    catch 
    {
        Write-output $_.Exception.Message
    }

}
#############################################################################################

################################## Remove the Template VM ###################################
Select-AzureRMSubscription -SubscriptionName $subName
$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
$diskName = $vm.StorageProfile.OsDisk.Name   

try
{
    Remove-AzureRmVM -ResourceGroupName $rgName -Name $vmName -Force -ErrorAction SilentlyContinue
    Write-Output "Removed VM $vmName"                                 
}
catch
{
    Write-output $_.Exception.Message
}
try
{
    Remove-AzureRmDisk -ResourceGroupName $rgName -Name $diskName -Force -ErrorAction SilentlyContinue
    Write-Output "Removed Disk $diskName"                                 
}
catch
{
    Write-output $_.Exception.Message
}
try
{                                 
    Remove-AzureRmNetworkInterface -ResourceGroupName $rgName -Name $vmName -Force -ErrorAction SilentlyContinue
    Write-Output "Removed NIC $vmName" 
}
catch
{
    Write-output $_.Exception.Message
}
try
{
    Remove-AzureRmNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName -Force -ErrorAction SilentlyContinue
    Write-Output "Removed NSG $nsgName" 
}
catch
{
    Write-output $_.Exception.Message
}
try
{
    Remove-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name $ipName -Force -ErrorAction SilentlyContinue
    Write-Output "Removed PIP $ipName" 
}
catch
{
    Write-output $_.Exception.Message
}
try
{
    Remove-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName  -Force -ErrorAction SilentlyContinue
    Write-Output "Removed vNet $vnetName"
}
catch
{
    Write-output $_.Exception.Message
}
try
{
    Remove-AzureRmSnapshot -ResourceGroupName $rgName -SnapshotName $SnapshotName -Force -ErrorAction SilentlyContinue
    Write-Output "Removed Snapshot $SnapshotName"
}
catch
{
    Write-output $_.Exception.Message
}
#############################################################################################