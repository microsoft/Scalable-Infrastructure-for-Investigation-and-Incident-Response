#######################################################################
#You might get issues with the provisioned state of some windows store apps
#The following show you how to remove the apps to enable sysprep to complete
#https://www.askvg.com/guide-how-to-remove-all-built-in-apps-in-windows-10/
#https://support.microsoft.com/en-us/help/2769827/sysprep-fails-after-you-remove-or-update-windows-store-apps-that-inclu
#https://blogs.technet.microsoft.com/mniehaus/2018/04/17/cleaning-up-apps-to-keep-windows-10-sysprep-happy/

#this will remove all windows store apps,
#Get-AppxPackage | Remove-AppxPackage
#######################################################################>

###################### Create or Set Log file #########################
$datetime = Get-Date -UFormat "%Y%m%d%H%M%S"
$filename = "Sysprep$datetime.txt"
$Location = "C:\UpdateLogs"
$LocationFile = "C:\UpdateLogs\$filename"

If((Test-Path $Location) -eq $False) 
{
    New-Item -Path "C:\" -name "UpdateLogs" -ItemType "directory"
} # End of folder exists test
If((Test-Path $LocationFile) -eq $False) 
{
    New-Item -Path $Location -Name $filename -ItemType File
} # End of file exist test
Else 
{
    "The $LocationFile is already there."
}
#######################################################################

########################## Start Sysprep ##############################
Write-Output "+ Starting Sysprep" | add-content $LocationFile

try
{
    $sysprep = 'C:\Windows\System32\Sysprep\Sysprep.exe'
    $arg = '/generalize /oobe /shutdown /quiet'
    $sysprep += " $arg"
    Invoke-Expression $sysprep
}
catch
{
    Write-Output "Error Running Sysprep" | add-content $LocationFile
    Write-Output $_.Exception.Message | add-content $LocationFile
}

Write-Output "+ Sysprep Executing" | add-content $LocationFile
#######################################################################