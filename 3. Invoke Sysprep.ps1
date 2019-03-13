######################################## variables ##########################################
$subid = #Subscription ID for the subscription containing the VM deployed to update
$rgName = #Resource Group containing the VM deployed for upgrading
$location = #Region in which the VM to update has been deployed
$vmName = #Name of the VM to be updates
$storageaccname = #Storage account within the Sub and Resource group, used to access PS1 files
$containerName = #Storage Container containing the PS1 Scripts
$FileName = #Name of the Script to call "3a. sysprep.ps1"
$extentionName = #Name for the Custom Script extension, has to be the same in the variables for "2. Invoke Updates"
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
#############################################################################################

################################ Login As Automation Account ################################

$storagekey = (Get-AzureRmStorageAccountKey -ResourceGroupName $rgName -Name $storageaccname| where-object{$Psitem.keyname -eq 'key1'}).value

try 
{
    Set-AzureRmVMCustomScriptExtension `
    -ResourceGroupName $rgName `
    -Location $location `
    -VMName $vmName `
    -Name $extentionName `
    -StorageAccountName $storageaccname `
    -StorageAccountKey $storagekey `
    -FileName $FileName `
    -ContainerName $containerName `
    -Run $FileName
}
catch 
{
    Write-Output "Failed to set custom script extension"
    Write-Output $_.Exception.Message
}
#############################################################################################