#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

#region Prep & signin

# sign in
Write-Host "Logging in...";
# Login-AzureRmAccount | Out-Null

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
$TemplateURI=New-Object System.Uri -ArgumentList @($TemplateRootUriString)

# Templates for the deploment (include filename)

$VnetTemplate = $TemplateURI.AbsoluteUri + "vnet-subnet.json"

#Parameter files for the deployment (include relative path to repo + filename)

$VnetParametersFile = $TemplateURI.AbsoluteUri + "parameters/vnet-subnet.parameters.json"

#endregion


# Create the resource group

if ( -not $ResourceGroup ) {
    Write-Output "Could not find resource group '$ResourceGroupName' - will create it"
    Write-Output "Creating resource group '$ResourceGroupName' in location '$Location'"
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $Location
}
else {
    Write-Output "Using existing resource group '$ResourceGroupName'"
}

$TemplateFilePath = "C:\Users\pierrer\Documents\Github\Igloo-POC\vnet-subnet.json"
$ParametersFilePath = "C:\Users\pierrer\Documents\Github\Igloo-POC\parameters\vnet-subnet.parameters.json"


# Start the deployment
Write-Output "Starting deployment"


#if ( Test-Path $ParametersFilePath ) {
#    Write-Host "found parameter file..."
#    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -TemplateParameterFile $ParametersFilePath | Out-Null
#}
#else {
#    Write-Host "Did not find parameter file..."
#    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath  | Out-Null
#}

Write-Host "Deploying virtual network..."

if (Invoke-WebRequest -Uri $VnetParametersFile)
{
    New-AzureRmResourceGroupDeployment -Name "vnet-deployment" -ResourceGroupName $networkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate -TemplateParameterFile $virtualNetworkParametersFile | Out-Null
}
else
{
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Name "vnet-deployment" -ResourceGroupName $networkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate | Out-Null

}

#New-AzureRmResourceGroupDeployment -Name "vnet-deployment" -ResourceGroupName $networkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate -TemplateParameterFile $virtualNetworkParametersFile | Out-Null

if ($error.Count -eq 0) {
    Write-Host "Deployment of Vnet in Resource Group '$networkResourceGroupName' failed"
}
else {
    Write-Host "Deployment of Vnet in Resource Group '$networkResourceGroupName' succeeded"
}
End region