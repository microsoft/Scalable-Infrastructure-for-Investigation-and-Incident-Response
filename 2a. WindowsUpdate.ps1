function Get-WIAStatusValue($value) 
{ 
    switch -exact ($value) 
    { 
        0 {"NotStarted"} 
        1 {"InProgress"} 
        2 {"Succeeded"} 
        3 {"SucceededWithErrors"} 
        4 {"Failed"} 
        5 {"Aborted"} 
    } 
}
    
$needsReboot = $false 
$UpdateSession = New-Object -ComObject Microsoft.Update.Session 
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

###################### Create or Set Log file #########################
$datetime = Get-Date -UFormat "%Y%m%d%H%M%S"
$filename = "WinUpdate$datetime.txt"
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

######################### Perform Update ##############################
Write-Output " - Searching for Updates" | add-content $LocationFile
$SearchResult = $UpdateSearcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0")
    
Write-Output " - Found [$($SearchResult.Updates.count)] Updates to Download and install" | add-content $LocationFile

$needsReboot = @()

foreach($Update in $SearchResult.Updates) 
{ 
    # Add Update to Collection 
    $UpdatesCollection = New-Object -ComObject Microsoft.Update.UpdateColl 
        
    if ( $Update.EulaAccepted -eq 0 ) 
    { 
        $Update.AcceptEula() 
    } 
        
    $UpdatesCollection.Add($Update) | out-null
    
    #Download 
    Write-Output " + Downloading Update $($Update.Title)" | add-content $LocationFile
    $UpdatesDownloader = $UpdateSession.CreateUpdateDownloader() 
    $UpdatesDownloader.Updates = $UpdatesCollection 
    $DownloadResult = $UpdatesDownloader.Download() 
    $Message = " - Download {0}" -f (Get-WIAStatusValue $DownloadResult.ResultCode) 
    Write-Output $message | add-content $LocationFile
    
    #Install 
    Write-Output " - Installing Update" | add-content $LocationFile
    $UpdatesInstaller = $UpdateSession.CreateUpdateInstaller() 
    $UpdatesInstaller.Updates = $UpdatesCollection 
    $InstallResult = $UpdatesInstaller.Install() 
    $Message = " - Install {0}" -f (Get-WIAStatusValue $DownloadResult.ResultCode) 
    Write-Output $message | add-content $LocationFile
    
    if ($installResult.rebootRequired){$needsReboot += "1"}
    
}

#Restart if needed
if($needsReboot.Contains("1")) 
{ 
    Write-Output "Restart Required" | add-content $LocationFile
    restart-computer -Force
}
#######################################################################