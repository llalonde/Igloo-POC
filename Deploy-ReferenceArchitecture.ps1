#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

#region Prep & signin

# sign in
Write-Host "Logging in...";
#Login-AzureRmAccount | Out-Null

# select subscription
$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
Write-Host 
Write-Host "Selecting subscription '$subscriptionId'";
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
Write-Host "setting location as '$Location'";
Write-Host 

#endregion

#region Set Template and Parameter location

# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

# Templates for the deploment (include filename)

$VnetTemplate = $TemplateURI.AbsoluteUri + "vnet-subnet.json"
$ASATemplate = $TemplateURI.AbsoluteUri + "ASA.json"

#Parameter files for the deployment (include relative path to repo + filename)

$VnetParametersFile = $TemplateURI.AbsoluteUri + "parameters/vnet-subnet.parameters.json"
$ASAParametersFile = $TemplateURI.AbsoluteUri + "parameters/asa.parameters.json"

#endregion


# Create the resource group

Get-AzureRmResourceGroup -Name $ResourceGroupName -ev notPresent -ea 0  | Out-Null

if ($notPresent) {
    Write-Output "Could not find resource group '$ResourceGroupName' - will create it"
    Write-Output "Creating resource group '$ResourceGroupName' in location '$Location'"
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Force | Out-Null

}
else {
    Write-Output "Using existing resource group '$ResourceGroupName'"
}


# Start the deployment
Write-Output "Starting deployment"

#region Deployment of virtual network
Write-Output "Deploying virtual network..."

if (Invoke-WebRequest -Uri $VnetParametersFile) {
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$VnetTemplate'"
    write-host " Parameter file:    '$VnetParametersFile'"
    write-host

    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -TemplateParameterUri $VnetParametersFile -Force | Out-Null
}
else {
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -Force | Out-Null

}

#endregion

Write-Output "Deploying Cisco ASAv appliance..."

$ASAResourceGroupName = $ResourceGroupName + "-ASA"

Get-AzureRmResourceGroup -Name $ASAResourceGroupName -ev notPresent -ea 0

if ($notPresent) {
    Write-Output "Could not find resource group '$ASAResourceGroupName' - will create it"
    Write-Output "Creating resource group '$ASAResourceGroupName' in location '$Location'"
    New-AzureRmResourceGroup -Name $ASAResourceGroupName -Location $Location -Force | Out-Null

}
else {
    Write-Output "Using existing resource group '$ASAResourceGroupName'"
}

if (Invoke-WebRequest -Uri $ASAParametersFile) {
    
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$ASATemplate'"
    write-host " Parameter file:    '$ASAParametersFile'"
    write-host
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -TemplateParameterUri $ASAParametersFile -Force | Out-Null
}
else {
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -Force | Out-Null

}
#region deployment of ASA firewall

#endregion

if ($error.Count -eq 0) {
    Write-Host "Deployment of Architecture failed"
}
else {
    Write-Host "Deployment of Architecture succeeded"
}
