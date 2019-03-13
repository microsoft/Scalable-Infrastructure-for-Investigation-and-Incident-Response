######################################## variables ##########################################
$subid = #Subsctiption in which you want to deploy the VM
$rgName = #Resource Group in which yo want to deploy the VM
$subnets = #CIDR ranges you want to be able to access the VM, e.g. "10.1.0.0/16", "192.168.2.0/24"
$location = #Region you want the VM deployed in
$vmName = #Name of the virtual machine you are want to create
$subnetName = #Name of the Subnet to be created with the VM
$vnetName = #Name of the Virtual Network to be created with the VM
$ipName = #Name of the Public IP address to be created with the VM
$nsgName = #Name of the Network Security Group to be created with the VM
$ImageName = #Name of the Image which the VM is to be deployed from
$vmSize = #SKU size for the VM you want to deploy https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
$Username = #Username for the account to be created on the VM
$KeyVault = #Keyvault name to store the password for the user account to be created on the VM
$PasswordName = #Name/ID of the password for the user account, which will be stored in keyvault
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

################################ Create User Account ########################################
try
{
	Add-Type -AssemblyName System.Web
	$securePassword = convertto-securestring ([System.Web.Security.Membership]::GeneratePassword(32,8)) -asplaintext -force
	Set-AzureKeyVaultSecret -VaultName $KeyVault -Name $PasswordName -SecretValue $securePassword
	$password = Get-AzureKeyVaultSecret -VaultName $KeyVault -Name $PasswordName
	$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($Username, $password.SecretValue) 
	Write-Output "Successfully created user and password pair. Password saved in KeyVault"
}
catch 
{
    Write-Output "Failed creating username and password pair."
    Write-Output $_.Exception.Message
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
	Write-Output "Created NSG and added custom RDP rule"
}
catch 
{
    Write-Output "Failed to Create NSG with custom RDP rule"
    Write-Output $_.Exception.Message	
}

try 
{	
	# Add our IPs to the Nsg
    # Remove the open rdp rule
    $nsg | Remove-AzureRmNetworkSecurityRuleConfig -Name "myRdpRule" > $null
    $index=100
    foreach ($cidr in $subnets) {
        $name = "rdp-rule-$index";
        $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name $name -Description "Allow RDP Access for Defined IPs" -Access Allow -Protocol * -Direction Inbound -Priority $index -SourceAddressPrefix $cidr -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 > $null
        $index++
    }
	$nsg | Set-AzureRmNetworkSecurityGroup > $null
	Write-Output "IPs added to RDP NSG"
}
catch 
{
    Write-Output "IPs failed to be added to RDP NSG"
    Write-Output $_.Exception.Message
}
############################################################################################

####################################### Create the VM ######################################
New-AzureRmVm `
    -ResourceGroupName $rgName `
    -Name $vmName `
    -ImageName $ImageName `
    -Location $location `
    -VirtualNetworkName $vnetName `
    -SubnetName $subnetName `
    -SecurityGroupName $nsgName `
    -PublicIpAddressName $ipName `
    -Credential $cred `
    -Size $vmSize
############################################################################################