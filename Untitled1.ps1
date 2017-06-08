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
Write-Host 
Write-Host "Connecting to subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId | out-null
Write-Host 

# select Resource Group
$ResourceGroupName = Read-Host -Prompt 'Input the resource group for your network'
Write-Host 
Write-Host "Selecting Resource Group '$ResourceGroupName'";
Write-Host 

# select Location
$Location = Read-Host -Prompt 'Input the Location for your network'
Write-Host 
Write-Host "Setting location as '$Location'";
Write-Host 

# select Location
$VMListfile = Read-Host -Prompt 'Input the Location of the list of VMs to be created'
Write-Host 
Write-Host

# Define a credential object
Write-Host "You Will now be asked for a UserName and Password that will be applied to all the Virtual Machine that will be created";
$cred = Get-Credential 

#endregion

#region Deployment of VM from VMlist.CSV
$VMList = Import-CSV $VMListfile

#The following workflow will move text files in parallel from one specefic location to another.
    
ForEach ( $VM in $VMList)
    {
    $VMName = $VM.ServerName
    $ASname = $VM.AvailabilitySet
    $VMsubnet = $VM.subnet
    $VMOS = $VM.OS
    $VMStorage = $vm.StorageAccount
    $VMSize = $vm.VMSize
    $VMDataDiskSize = $vm.DataDiskSize

        if ($VMName -ne "None")
        {
            write-host $ASname
            start-job -ScriptBlock {New-AzureRmAvailabilitySet -Location $Location -Name $ASname -ResourceGroupName $ResourceGroupName} -ArgumentList $ASname, $Location, $ResourceGroupName
        }
    }

#endregion