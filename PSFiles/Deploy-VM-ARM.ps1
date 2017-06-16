#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$starttime = get-date

#region Prep & signin

# sign in
Write-Host "Logging in ...";
Login-AzureRmAccount | Out-Null

# select subscription
$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
Select-AzureRmSubscription -SubscriptionID $subscriptionId | out-null

# select Resource Group
$ResourceGroupName = Read-Host -Prompt 'Input the resource group for your network'

# select Location
$Location = Read-Host -Prompt 'Input the Location for your network'

# select Location
$VMListfile = Read-Host -Prompt 'Input the Location of the list of VMs to be created'

# Define a credential object
$cred = Get-Credential -Message "You Will now be asked for a UserName and Password that will be applied to the windows Virtual Machine that will be created"

# Define a credential object
$Linuxcred = Get-Credential -Message "You Will now be asked for a UserName and Password that will be applied to the linux Virtual Machine that will be created"

#endregion


#region Deployment of VM from VMlist.CSV
$VMList = Import-CSV $VMListfile
ForEach ( $VM in $VMList) {
    $VMName = $VM.ServerName
    $ASname = $VM.AvailabilitySet
    $VMsubnet = $VM.subnet
    $VMOS = $VM.OS
    $VMStorage = $vm.StorageAccount
    $VMSize = $vm.VMSize
    $VMDataDiskSize = $vm.DataDiskSize
    $DataDiskName = $VM.ServerName + "Data"
    $VMImageName = $vm.ImageName
    $adminPassword = $cred.password | convertfrom-securestring
    $adminUsername = $cred.password

    $vnet = Get-AzureRMVirtualNetwork -ResourceGroupName $ResourceGroupName
    $storageAcc = Get-AzureRmStorageAccount -AccountName $VMStorage -ResourceGroupName $ResourceGroupName
    
    Write-Host "Processing '$VMName'...."
    Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName -ev notPresent -ea 0  | Out-Null

    if ($notPresent) {
        Write-Host $AS
        New-AzureRmResourceGroupDeployment -Name $AS -ResourceGroupName $ResourceGroupName -TemplateUri $ASTemplate -TemplateParameterObject `
        @{  Image
            virtualMachineName = $VMName `
            virtualMachineSize = $VMSize `
            availabilitySetName = $ASname `
            adminUsername = $adminUsername `
            adminPassword = $adminPassword `
            virtualNetworkName = $vnet.Name `
            networkInterfaceName = $VMName `
            subnetName = $VMsubnet `
            diagnosticsStorageAccountName = $VMStorage `
            domainToJoin = "iglooaz.local" `
            domainUsername = "iglooaz\sysadmin" `
            domainPassword = "P@ssw0rd!234" `
            storageAccountName = $VMStorage `
        }
    }
}

$endtime = get-date
$procestime = $endtime - $starttime
$time = "{00:00:00}" -f $procestime.Minutes
write-host " Deployment completed in '$time' "
#endregion