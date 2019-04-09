######################################## variables ##########################################
$subid = #Subsctiption ID in which your VM is deployed
$subName = #Subsctiption Name iin which your VM is deployed
$rgName = #Resource Group in which your VM is deployed
$keyVaultName = #Name of the Keyvault containing the secret for this Vm to be deleted
#############################################################################################

#############################################################################################
Write-Host "         _______"
Write-Host "        |.-----.|"
Write-Host "        ||x . x||"
Write-Host "        ||_.-._||"
Write-Host "        ---)-(--- "
Write-Host "       __[=== o]___"
Write-Host "      |:::::::::::|\"
Write-Host "      --=========--()"
Write-Host "`n"
Write-Host "`n"
Write-Host "This script will delete the VM specified"
Write-Host "`n"
Write-Host "### Checking Windows Azure PowerShell version: " -NoNewLine
Try { 
	Import-Module AzureRM -MinimumVersion 3.0.0 -ErrorAction Stop
} Catch {
	Write-Host -ForegroundColor Red "Failed!"
	Write-Host "Please ensure you have the latest version of Azure PowerShell (please see https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/)."
	exit
}
Write-Host -ForegroundColor Green "Good!"
Write-Host "### Logging into Azure (please use your user@domain)"
Login-AzureRmAccount -ErrorAction Stop
Set-AzureRMContext -SubscriptionId $subid
#############################################################################################

################################### Get User Input ##########################################
Do { $UniqueID = Read-Host "Please specify a Unique ID for the VM you wish to delete (e.g. Case Number)" } while ($UniqueID -eq "")

$vmName = "$UniqueID"
$vnetName = "$UniqueID-Vnet"
$nsgName = "$UniqueID-NSG"
$ipName = "$UniqueID-PIP"

$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
$diskName = $vm.StorageProfile.OsDisk.Name 

Write-Host -ForegroundColor Green "`n!!!! IMPORTANT !!!!"
Write-Host "Please review.  The following items will be deleted permanently:"
Write-Host "              VM: $vmName"
Write-Host "             NIC: $vmName"
Write-Host "            Disk: $diskName"
Write-Host "             NSG: $nsgName"
Write-Host "             PIP: $ipName"
Write-Host "`n"
$confirm = Read-Host "Enter the Unique ID again to proceed with deletion, otherwise press <ENTER> to cancel"
if ($confirm -ne $UniqueID)
{
	Write-Host -ForegroundColor Red "Cancelled!"
	exit
}
#############################################################################################

###################################### Remove the  VM #######################################
Select-AzureRMSubscription -SubscriptionName $subName

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

################################### Remove Secret ###########################################
Write-Host "Removing the Secrets for $UniqueID from KeyVault $keyVaultName."
try
{
	Remove-AzureKeyVaultSecret -VaultName $keyVaultName -Name $UniqueID -Force
	Write-Host "Done!"
}
catch
{
	Write-Output $_.Exception.Message
}
#############################################################################################