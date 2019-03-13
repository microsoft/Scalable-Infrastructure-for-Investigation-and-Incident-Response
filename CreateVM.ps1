######################################## variables ##########################################
$subid = #Subsctiption in which you want to deploy the VM
$imageRG = #Name of the Image file created in "3. Create all Images and Cleanup"
$rgName = #Resource Group in which you want to deploy the VM
$keyVaultName = #Name of the Keyvault within the RG you are deploying the VMs
$subnets = #CIDR ranges you want to be able to access the VM, e.g. "10.1.0.0/16", "192.168.2.0/24"
$vmSize = #SKU size for the VM you want to deploy https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
#############################################################################################

#############################################################################################
Write-Host  "                 .----."
Write-Host  "     .---------. | == |"
Write-Host  '     |.-"""""-.| |----|'
Write-Host  "     ||       || | == |"
Write-Host  "     ||       || |----|"
Write-Host  "     |'-.....-'| |::::|"
Write-Host  '     `"")---(""` |___.|'
Write-Host  "    /:::::::::::\" _  ""
Write-Host "`n"
Write-Host "This script will create a VM from an template in a region to be specified"
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
Do { $UniqueName = Read-Host "Please specify a Unique ID for the VM (e.g. Case Number):" } while ($UniqueName -eq "")

Write-Host "`n### Locations available ###"
$validLocations = Get-AzureRMLocation | Sort-Object Location | ForEach-Object {$_.Location}
$storageLocations = Get-AzureRMLocation | where-object Providers -Contains Microsoft.Storage |Sort-Object Location | ForEach-Object {$_.Location}
$validLocations

Do {
	$location = Read-Host "Enter Location"
} while (-not $validLocations.Contains($location))

if ($location -notin $storageLocations){$location = "eastus"}

$vmName = "$UniqueName"
$DomainLabel = "$UniqueName"
$imageName = "tmpltimage$location"
$vnetName = "$UniqueName-Vnet"
$subnetName = "$UniqueName-Subnet"
$nsgName = "$UniqueName-NSG"
$ipName = "$UniqueName-PIP"
#############################################################################################

################################ Create User Account ########################################
try
{
    $Username = Read-Host "Enter Username"
    Add-Type -AssemblyName System.Web
	$securePassword = convertto-securestring ([System.Web.Security.Membership]::GeneratePassword(32,8)) -asplaintext -force
	$null = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $UniqueName -SecretValue $securePassword 
	$password = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $UniqueName
	$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($Username, $password.SecretValue)  
	Write-Host -ForegroundColor Green "`nSuccessfully created user and password pair. Username: $Username, Passoword: saved in KeyVault" 
}
catch 
{
    Write-Host -ForegroundColor Red "Failed to Create User Passowrd Pair"
    Write-Host $_.Exception.Message
}
#############################################################################################

######################################## Create NSG #########################################
try
{
	#Create the NSG
    $rdpRule = New-AzureRmNetworkSecurityRuleConfig -Name myRdpRule -Description "Allow RDP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
    -SourceAddressPrefix Internet -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

    $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rgName -Location $location `
		-Name $nsgName -SecurityRules $rdpRule -Force
	Write-Host -ForegroundColor Green "Created NSG and added custom RDP rule"
}
catch 
{
    Write-Host -ForegroundColor Red "Failed to Create NSG with custom RDP rule"
    Write-Host $_.Exception.Message	
}

try 
{	
	# Add our CORP IPs to the Nsg
    # Remove the open rdp rule
    $nsg | Remove-AzureRmNetworkSecurityRuleConfig -Name "myRdpRule" > $null
    $index=100
    foreach ($cidr in $subnets) {
        $name = "rpd-in-$index";
        $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name $name -Description "Allow RDP From Specified CIDR Range" -Access Allow -Protocol * -Direction Inbound -Priority $index -SourceAddressPrefix $cidr -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 > $null
        $index++
    }
	$nsg | Set-AzureRmNetworkSecurityGroup > $null
	Write-Host -ForegroundColor Green "IPs added to RDP NSG"
}
catch 
{
    Write-Host -ForegroundColor Red "IPs failed to be added to RDP NSG"
    Write-Host $_.Exception.Message
}
############################################################################################

####################################### Create the VM ######################################
$ImageId = "/subscriptions/$subID/resourceGroups/$imageRG/providers/Microsoft.Compute/images/$imageName"

New-AzureRmVm `
    -ResourceGroupName $rgName `
    -Location $location `
    -Name $vmName `
    -Credential $cred `
    -VirtualNetworkName $vnetName `
    -SubnetName $subnetName `
    -PublicIpAddressName $ipName `
    -DomainNameLabel $DomainLabel.ToLower() `
    -SecurityGroupName $nsgName `
    -Image $imageID `
    -Size $vmSize

############################################################################################

#################################### Return Variables ######################################
# Verify that it was created
#$vmList = Get-AzureRmVM -ResourceGroupName $rgName
Write-Host -ForegroundColor Green "VM $vmName created successfully.  To login to the VM, use the following information:"
Write-Host -ForegroundColor Green "RDP (port 3389) to" (Get-AzureRmPublicIpAddress -name $ipName -ResourceGroupName $rgName).IpAddress
Write-Host -ForegroundColor Green "RDP (port 3389) to" (Get-AzureRmPublicIpAddress -name $ipName -ResourceGroupName $rgName).DnsSettings.Fqdn
Write-Host -ForegroundColor Green "Username: $Username"
Write-Host -ForegroundColor Green "The password for this VM is in the Key Vault: $keyVaultName, within the RG $rgName, with the name - $UniqueName"
############################################################################################