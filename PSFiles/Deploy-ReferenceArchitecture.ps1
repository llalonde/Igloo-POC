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
$Subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId | out-null

# select Resource Group
$ResourceGroupName = Read-Host -Prompt 'Input the resource group for your network'

# select Location
$Location = Read-Host -Prompt 'Input the Location for your network'

# select Location
$VMListfile = Read-Host -Prompt 'Input the Location of the list of VMs to be created'

#endregion

#region Set Template and Parameter location
# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

$VnetTemplate = $TemplateURI.AbsoluteUri + "vnet-subnet.json"
$ASATemplate = $TemplateURI.AbsoluteUri + "ASA.json"
$StorageTemplate = $TemplateURI.AbsoluteUri + "VMStorageAccount.json"
$ASTemplate = $TemplateURI.AbsoluteUri + "AvailabilitySet.json"
$AATemplate = $TemplateURI.AbsoluteUri + "AzrAutoAccount.json"
$NSGTemplate = $TemplateURI.AbsoluteUri + "nsg.azuredeploy.json"

#Parameter files for the deployment (include relative path to repo + filename)

$VnetParametersFile = $TemplateURI.AbsoluteUri + "parameters/vnet-subnet.parameters.json"
$ASAParametersFile = $TemplateURI.AbsoluteUri + "parameters/asa.parameters.json"
$StorageParametersFile = $TemplateURI.AbsoluteUri + "parameters/VMStorageAccount.parameters.json"

#endregion
#region Create the resource group

# Start the deployment
Write-Output "Starting deployment"

Get-AzureRmResourceGroup -Name $ResourceGroupName -ev notPresent -ea 0  | Out-Null

if ($notPresent) {
    Write-Output "Could not find resource group '$ResourceGroupName' - will create it."
    Write-Output "Creating resource group '$ResourceGroupName' in location '$Location'...."
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Force | out-null

}
else {
    Write-Output "Using existing resource group '$ResourceGroupName'"
}

#endregion
#region Deployment of virtual network
Write-Output "Deploying virtual network..."

if (Invoke-WebRequest -Uri $VnetParametersFile) {
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$VnetTemplate'"
    write-host " Parameter file:    '$VnetParametersFile'"
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -TemplateParameterUri $VnetParametersFile -Force | out-null
}
else {
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -Force | out-null
}

#endregion
#region Deploy Cisco ASA appliance 
Write-Host 
Write-Output "Deploying Cisco ASAv appliance..."
$ASAResourceGroupName = $ResourceGroupName + "-ASA"
Get-AzureRmResourceGroup -Name $ASAResourceGroupName -ev notPresent -ea 0 | out-null
if ($notPresent) {
    Write-Output "Could not find resource group '$ASAResourceGroupName' - will create it"
    Write-Output "Creating resource group '$ASAResourceGroupName' in location '$Location'...."
    New-AzureRmResourceGroup -Name $ASAResourceGroupName -Location $Location -Force | out-null
}
else {
    Write-Output "Using existing resource group '$ASAResourceGroupName'"
}
if (Invoke-WebRequest -Uri $ASAParametersFile) {
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$ASATemplate'"
    write-host " Parameter file:    '$ASAParametersFile'"
    New-AzureRmResourceGroupDeployment -Name "ASA-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -TemplateParameterUri $ASAParametersFile -Force | out-null
}
else {
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    New-AzureRmResourceGroupDeployment -Name "ASA-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -Force | out-null
}

#endregion
#region Deployment of Storage Account
Write-Output "Deploying Storage Accounts..."

if (Invoke-WebRequest -Uri $StorageParametersFile) {
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$StorageTemplate'"
    write-host " Parameter file:    '$StorageParametersFile'"
    New-AzureRmResourceGroupDeployment -Name "Storage-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $StorageTemplate -TemplateParameterUri $StorageParametersFile -Force | out-null
}
else {
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    New-AzureRmResourceGroupDeployment -Name "Storage-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $StorageTemplate -Force | out-null
}

#endregion

#region Deployment of Availability Sets
$ASList = Import-CSV $VMListfile | Where-Object {$_.AvailabilitySet -ne "None"}
$ASListUnique = $ASList.AvailabilitySet | select-object -unique

ForEach ( $AS in $ASListUnique)
{
    New-AzureRmResourceGroupDeployment -Name $AS -ResourceGroupName $ResourceGroupName -TemplateUri $ASTemplate -TemplateParameterObject @{ASname=$AS}
}
#endregion

#region Deployment of Availability Sets

$NSGList = Import-CSV $VMListfile | Where-Object {$_.subnet -ne "None"}
$NSGListUnique = $NSGList.subnet | select-object -unique

ForEach ( $NSG in $NSGListUnique){
    $NSGName=$NSG+"-nsg"
    New-AzureRmResourceGroupDeployment -Name $NSG -ResourceGroupName $ResourceGroupName -TemplateUri $NSGTemplate -TemplateParameterObject @{networkSecurityGroupName=$NSGName} -Force | out-null
}
#endregion
#region Deployment of Automation Account and RunBook

#New-AzureRmResourceGroupDeployment -Name "Automation" -ResourceGroupName $ResourceGroupName -TemplateUri $AATemplate | out-null

# Create a Run As account by using a service principal

# end of script

$endtime = get-date
$procestime = $endtime - $starttime
$time = "{00:00:00}" -f $procestime.Minutes
write-host " Deployment completed in '$time' "









