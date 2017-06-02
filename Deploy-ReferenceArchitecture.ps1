#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

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
if ( Test-Path $ParametersFilePath ) {
    Write-Host "found parameter file..."
    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -TemplateParameterFile $ParametersFilePath | Out-Null
}
else {
    Write-Host "Did not find parameter file..."
    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath  | Out-Null
}

