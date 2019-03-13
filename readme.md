The collection of scripts in this repository plus this readme will guide a user through the creation of an automated solution to create a templated image of a Windows VM which is updated and maintained weekly.

Step 0. - Pre Requisites:

    It is expected that the user will have access to:
        *   An Azure Subscription or MSDN Account with Azure Credits.
        *   Rights within azure to create and edit resources.

Step 1 - Environment Setup:

    *   Create a Resource Group specifically for the use of storing and maintianing the VM template, images and automation
    *   Within the Resourse group add an Automation Account, by using the Add option in the Resource Group, searching for and selecting Automation
        *   Provide a relevant name for the automation account, ensure it is in the correct subscription and resource group, ensure the 'Create Azure Run As Account' it selected 'yes'
    *   Select the newly created Automation Account, select modules in the left hand menu and ensure the following modules are present. if not use the 'add a module' and follow the UI instuctions to add them:
        *   Azure
        *   Azure.Storage
        *   AzureRM.Automation
        *   AzureRM.Compute
        *   AzureRM.KeyVault
        *   AzureRM.Network
        *   AzureRM.Profile
        *   AzureRM.Resources
        *   AzureRM.Sql
        *   AzureRM.Storage
    * Within the Resourse group add Key Vault, by using the Add option in the Resource Group, searching for an selecting Key Vault 
        *   Provide a relevant name for the Key Vault, ensure it is in the correct Subscription and Resource Group.
            *   Select 'Access Policies' in the Key Vault Creation Page, which should have 1 principal (you). In the Access Policies menu select 'Add New'
                *   In the Add Access Policy Menu, select 'Secret Management' as the Template. Click Add Principal and seach for and select the name of the previously created automation account
        *   OK everything and Create the Key Vault
    * Within the Resourse group add Storage Account, by using the Add option in the Resource Group, searching for an selecting 'Storage account - blob, file, table, queue' 
        * Provide a relevant name for the Storage Account, ensure it is in the correct Subscription and Resource Group.
            * Select Stoage Account from the Resource Group Dashboard, in the left hand menu select 'Blobs' under the 'Blob Service' section
                * In the Blobs pane that loads, click on '+ Container' at the top of the pane
                    * Provide a name for this blob store (As it is going to be used to store scripts I recommend calling it 'scripts'), ensure the access level is set to 'Private'
                * Ok Eveything to create the Blog container.
        * Browse to the Blob Container in the Azure Portal, (Resource Group > Storage Account > Blob Container)
            * in the container pane, select the upload options and upload the following 2 scripts to this location:
                1. "2a. WindowsUpdate.ps1"
                2. "3a. Sysprep.ps1"


Step 2 - Create Automation Runbooks:

    *  Browse to the Runbooks section of the Automation Account previously created (Resource Group > Automation Account > Runbooks)
        1.  Add a runbook, select 'Create a new runbook', give this a name ("DeployTemplateVM"), Select 'PowerShell' in Runbook type then create the Runbook
            *   When the Runbook is created it will take you to the 'Edit PowerShell Runbook' pane, enter the code from '1. Build New Template to Update.ps1'
            *   enter the relevant variables in the top section of the code and use the test pane to ensure the code executes correctly.
        2.  Add a runbook, select 'Create a new runbook', give this a name ("InvokeUpdate"), Select 'PowerShell' in Runbook type then create the Runbook
            *   When the Runbook is created it will take you to the 'Edit PowerShell Runbook' pane, enter the code from '2. Invoke Updates.ps1'
            *   enter the relevant variables in the top section of the code and use the test pane to ensure the code executes correctly.
        3.  Add a runbook, select 'Create a new runbook', give this a name ("InvokeSysprep"), Select 'PowerShell' in Runbook type then create the Runbook
            *   When the Runbook is created it will take you to the 'Edit PowerShell Runbook' pane, enter the code from '3. Invoke Sysprep.ps1'
            *   enter the relevant variables in the top section of the code and use the test pane to ensure the code executes correctly.
        4.  Add a runbook, select 'Create a new runbook', give this a name ("SnapshotAndCopy"), Select 'PowerShell' in Runbook type then create the Runbook
            *   When the Runbook is created it will take you to the 'Edit PowerShell Runbook' pane, enter the code from '4. Snapshot and Move to SAs.ps1'
            *   enter the relevant variables in the top section of the code and use the test pane to ensure the code executes correctly.
        5.  Add a runbook, select 'Create a new runbook', give this a name ("ImageAndCleanup"), Select 'PowerShell' in Runbook type then create the Runbook
            *   When the Runbook is created it will take you to the 'Edit PowerShell Runbook' pane, enter the code from '5. Create all Images and Cleanup.ps1'
            *   enter the relevant variables in the top section of the code and use the test pane to ensure the code executes correctly.

Step 3 - Create VM (Template/Baseline):

    *   Create a Windows VM in azure, (whatever version of windows you would like) install relevant tools ect. to setup the environemnt.
    *   Once you have built the VM and installed all required software, you need to use 'sysprep.exe' to prepare the VM for imaging.
    *   In the VM, open Powershell as an Administrator enter the following, bare in mind that this will shutdown the VM and remove all user specific files.:
        
        >C:\Windows\System32\sysprep\sysprep.exe /generalize /oobe /shutdown
        
    *   The VM will disconnect the RDP session. After while you will see the dashed lines for the resource useage data for the VM in the VM overview, this signifies the sysprep has completed.

Step 4 - Create set of images.

    * Once the Sysprep has completed, browse to the runbook "SnapshotAndCopy" (Resource Group > SnapshotAndCopy)
        * In the Runbook, Click the 'Start' button at the top of the screen to initiate the first half of the image creation process
    * For obvious reasons Azure Runbooks will not run forwever and the copy process takes a few hours. Wait about 3 hours from the time the 'SnapshotAndCopy' was initiated
    * After waiting a couple of hours, browse to the runbook "ImageAndCleanup" (Resource Group > ImageAndCleanup)
        * In the Runbook, Click the 'Start' button at the top of the screen to initiate the second half of the image creation process.

Step 5 - Check and Test.

    * Once completed, browse to your Resource Group, there you should see an image for all the locations you specified along with the runbooks, automation account, key vault and storage account required for the automation.
    * It is recommended to test a VM deployment from one of the newlsy created images to ensure that eveything has worked as expected.
        * You can do this by running the script "CreateInvestigationVM_v2.ps1" on you local machine (you will need to configure the script with relevant variables)
            * This will create a VM from one of the images you have created using the automation, (depending on your configuration you may need to create a new Resource Group with a Key Vault)

Step 6 - Create Schedual.

    * After everything has been checked and you are happy to automate the process of updating the template and deploying updated images automatically, you need to create a scheduel to execute the runbooks in order.
    * Navigte to the Schedules within the Automation Account (Resource Group > Automation Account > Schedules).
    * Select "+ Add a schedule", provide a name, a start date and time, a timezone and a reccurrence, examples are as follows:
        * Name                          Start Date / Time       Time Zone       Reccurrence
        * Deploy_Saturday_PM            05/01/2019 23:00        UTC             Every 1 week on a Sunday                                     
        * Update_Sunday_AM_1            06/01/2019 00:00        UTC             Every 1 week on a Sunday
        * Update_Sunday_AM_2            06/01/2019 01:00        UTC             Every 1 week on a Sunday
        * Sysprep_Sunday_AM             06/01/2019 02:00        UTC             Every 1 week on a Sunday
        * CopyToSAs_Sunday_AM           06/01/2019 04:00        UTC             Every 1 week on a Sunday
        * ImageAndCleanup_Sunday_AM     06/01/2019 07:00        UTC             Every 1 week on a Sunday
    * Finally you need to Assing the relevant Runbook to the Schedule you have just created. Navigate to each runbook (Resourse Group > Runbook)
        * Select Schedules in the left side menu, select 'Link a schedule to your runbook', select the relevant schedule then click OK to confirm the selection.
        * examples are as follows:
            * Schedule Name                 Associated Runbook
            * Deploy_Saturday_PM            DeployTemplateVM                             
            * Update_Sunday_AM_1            InvokeUpdate
            * Update_Sunday_AM_2            InvokeUpdate
            * Sysprep_Sunday_AM             InvokeSysprep
            * CopyToSAs_Sunday_AM           SnapshotAndCopy
            * ImageAndCleanup_Sunday_AM     ImageAndCleanup

Thats it, you now have an automated setup to ensure regionally deployed images are updated regulaly.