#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$starttime = get-date

# sign in
Write-Host "Logging in ...";
#Login-AzureRmAccount | Out-Null

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
Write-Host "You Will now be asked for a UserName and Password that will be applied to all the Virtual Machine that will be created";
$cred = Get-Credential

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

$VMTemplate = $TemplateURI.AbsoluteUri + "VM.json"
$ASTemplate = $TemplateURI.AbsoluteUri + "AvailabilitySet.json"

#Parameter files for the deployment (include relative path to repo + filename)

$VMParametersFile = $TemplateURI.AbsoluteUri + "parameters/VM.parameters.json"

#region Deployment of VM from VMlist.CSV

$VMList = Import-CSV $VMListfile

#region Deployment of Availability Sets
$ASList = Import-CSV $VMListfile | Where-Object {$_.AvailabilitySet -ne "None"}
$ASListUnique = $VMList.AvailabilitySet | select-object -unique

ForEach ( $AS in $ASListUnique){
    New-AzureRmResourceGroupDeployment -Name $AS -ResourceGroupName $ResourceGroupName -TemplateUri $ASTemplate -TemplateParameterObject @{ASname=$AS} -Force | out-null
}

ForEach ( $VM in $VMList)
{

    $VMName = $VM.ServerName
    $ASname = $VM.AvailabilitySet
    $VMsubnet = $VM.subnet
    $VMOS = $VM.OS
    $VMStorage = $vm.StorageAccount
    $VMSize = $vm.VMSize
    $VMDataDiskSize = $vm.DataDiskSize

    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Templatefile C:\Users\pierrer\Documents\Github\Igloo-POC\VM.json -TemplateParameterObject @{ `
    ResourceGroupName=$ResourceGroupName; `
    virtualMachineName=$VMName; `
    virtualMachineSize=$VMSize; `
    adminUsername="sysadmin"; `
    adminPassword="P@ssw0rd!234"; `
    virtualNetworkName="Vnet-Igloo-POC"; `
    networkInterfaceName=$VMName+"-nic"; `
    availabilitySetName=$ASname; `
    storageAccountName=$VMStorage; `
    subnetName=$VMsubnet; `
    availabilitySetPlatformFaultDomainCount='2'; `
    availabilitySetPlatformUpdateDomainCount='5'; `
    diagnosticsStorageAccountName=$VMStorage `
    } `
    -DeploymentDebugLogLevel All -Name $ASname


}
