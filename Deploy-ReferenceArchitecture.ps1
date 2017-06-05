#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

#region Prep & signin

# sign in
Write-Host "Logging in ...";
Login-AzureRmAccount | Out-Null

# select subscription
$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
Write-Host 
Write-Host "Connecting to subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId | Out-Null
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

#endregion

#region Set Template and Parameter location

# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

# Templates for the deploment (include filename)

$VnetTemplate = $TemplateURI.AbsoluteUri + "vnet-subnet.json"
$ASATemplate = $TemplateURI.AbsoluteUri + "ASA.json"
$StorageTemplate = $TemplateURI.AbsoluteUri + "VMStorageAccount.json"
$VMListfile=$StorageTemplate = $TemplateURI.AbsoluteUri + "VMList.csv"



#Parameter files for the deployment (include relative path to repo + filename)

$VnetParametersFile = $TemplateURI.AbsoluteUri + "parameters/vnet-subnet.parameters.json"
$ASAParametersFile = $TemplateURI.AbsoluteUri + "parameters/asa.parameters.json"
$StorageParametersFile = $TemplateURI.AbsoluteUri + "parameters/VMStorageAccount.parameters.json"




#endregion


# Create the resource group

Get-AzureRmResourceGroup -Name $ResourceGroupName -ev notPresent -ea 0  | Out-Null

if ($notPresent) {
    Write-Host
    Write-Host 
    Write-Output "Could not find resource group '$ResourceGroupName' - will create it."
    Write-Host 
    Write-Host
    Write-Output "Creating resource group '$ResourceGroupName' in location '$Location'...."
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Force | Out-Null

}
else {
    Write-Host
    Write-Host 
    Write-Output "Using existing resource group '$ResourceGroupName'"
}


# Start the deployment
Write-Host 
Write-Host 
Write-Output "Starting deployment"

#region Deployment of virtual network
Write-Host 
Write-Host 
Write-Output "Deploying virtual network..."

if (Invoke-WebRequest -Uri $VnetParametersFile) {
    Write-Host 
    Write-Host 
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$VnetTemplate'"
    write-host " Parameter file:    '$VnetParametersFile'"
    write-host

    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -TemplateParameterUri $VnetParametersFile -Force | Out-Null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -Force | Out-Null

}

#endregion


#region Deploy Cisco ASA appliance 
Write-Host 
Write-Output "Deploying Cisco ASAv appliance..."

$ASAResourceGroupName = $ResourceGroupName + "-ASA"

Get-AzureRmResourceGroup -Name $ASAResourceGroupName -ev notPresent -ea 0 | Out-Null

if ($notPresent) {
    Write-Host 
    Write-Host 
    Write-Output "Could not find resource group '$ASAResourceGroupName' - will create it"
    Write-Host 
    Write-Host 
    Write-Output "Creating resource group '$ASAResourceGroupName' in location '$Location'...."
    New-AzureRmResourceGroup -Name $ASAResourceGroupName -Location $Location -Force | Out-Null

}
else {
    Write-Host 
    Write-Host 
    Write-Output "Using existing resource group '$ASAResourceGroupName'"
}

if (Invoke-WebRequest -Uri $ASAParametersFile) {
    Write-Host 
    Write-Host 
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$ASATemplate'"
    write-host " Parameter file:    '$ASAParametersFile'"
    write-host
    New-AzureRmResourceGroupDeployment -Name "ASA-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -TemplateParameterUri $ASAParametersFile -Force | Out-Null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Name "ASA-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -Force | Out-Null

}

#endregion

#region Deployment of Storage Account
Write-Host 
Write-Host 
Write-Output "Deploying Storage Accounts..."

if (Invoke-WebRequest -Uri $StorageParametersFile) {
    Write-Host 
    Write-Host 
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$StorageTemplate'"
    write-host " Parameter file:    '$StorageParametersFile'"
    write-host

    New-AzureRmResourceGroupDeployment -Mode Complete -Name "Storage-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $StorageTemplate -TemplateParameterUri $StorageParametersFile -Force | Out-Null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "Storage-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $StorageTemplate -Force | Out-Null

}

#endregion



if ($error.Count -eq 0) {
    Write-Host 
    Write-Host 
    Write-Host "Deployment of Architecture failed"
}
else {
    Write-Host 
    Write-Host 
    Write-Host "Deployment of Architecture succeeded"
}

#region Read in List of VM to create

Write-Host 
Write-Host 
Write-Host "Read in list of VM to Create...."
 
$VMList = Import-CSV $VMListfile 
 
$Counter = 1
 
foreach ($VM in $VMList) {
    $Counter++
}
Write-Host " '$counter' VM in the list"
