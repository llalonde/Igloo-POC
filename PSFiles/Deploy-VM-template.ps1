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
Write-Host "You Will now be asked for a UserName and Password that will be applied to the windows Virtual Machine that will be created";
$Wincred = Get-Credential 

# Define a credential object
Write-Host "You Will now be asked for a UserName and Password that will be applied to the linux Virtual Machine that will be created";
$Linuxcred = Get-Credential 
#endregion

#region Set Template and Parameter location

$Date=Get-Date -Format yyyyMMdd

# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

$VMFromUserImage = $TemplateURI.AbsoluteUri + "VMFromUserImage.json"

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

    switch ($VMImageName)
    {
        'CentOS6' {$ImageUri = 'https://standardsaiwrs4jpmap5k4.blob.core.windows.net/vhds/centos6temp220170612211517.vhd'}
        'CentOS7' {$ImageUri = 'https://standardsaiwrs4jpmap5k4.blob.core.windows.net/vhds/centos7temp20170612170035.vhd'}
        'Windows' {$ImageUri = 'https://standardsaiwrs4jpmap5k4.blob.core.windows.net/vhds/Windows2012R220170612221756.vhd'}
        Default {Write-Host "No Image Defined...."}
    }
    
    switch ($VMOS)
    {
        "Linux" {$cred = $Linuxcred}
        "Windows" {$cred = $Wincred}
        Default {Write-Host "No OS Defined...."}
    }

    $vnet=Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName

    Write-Host "Processing '$VMName'...."
    Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName -ev notPresent -ea 0  | Out-Null

    if ($notPresent) {
        if ($ASname -ne "None") {
        
            Write-Output "Deploying '$VMName'..."
            $DeploymentName = 'VM-'+$VMName + '-'+ $Date
            
            $Vnet_Results = New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $VMFromUserImage -TemplateParameterObject `
                @{ `
                    customVmName= $VMName; `
                    bootDiagnosticsStorageAccountName='standardsaiwrs4jpmap5k4'; `
                    ResourceGroupName=$ResourceGroupName; `
                    osDiskVhdUri='$ImageUri'; `
                    dnsLabelPrefix=''; `
                    adminUsername=$cred.UserName; `
                    adminPassword=$cred.Password; `
                    osType=$VMOS; `
                    vmSize=$VMSize; `
                    VnetName=$vnet.Name;`
                    SubnetName=$VMsubnet; `
                    domainToJoin='Iglooaz.local';`
                    domainToJoindomainJoinOptions= '3'; `
                } -Force | out-null
        }
        else {
            write-host "Virtual Machine not part of an availability set"
        }
    }
}

#endregion