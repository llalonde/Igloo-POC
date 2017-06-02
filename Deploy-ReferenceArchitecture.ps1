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
$networkResourceGroupName = Read-Host -Prompt 'Input the resource group for your network'
Write-Host 
Write-Host "Selecting Resource Group '$networkResourceGroupName'";
Write-Host 

# select Location
$Location = Read-Host -Prompt 'Input the Location for your network'
Write-Host 
Write-Host "Selecting subscription '$Location'";
Write-Host 

$buildingBlocksRootUriString = $env:TEMPLATE_ROOT_URI
if ($buildingBlocksRootUriString -eq $null) {
  $buildingBlocksRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
}

if (![System.Uri]::IsWellFormedUriString($buildingBlocksRootUriString, [System.UriKind]::Absolute)) {
  throw "Invalid value for TEMPLATE_ROOT_URI: $env:TEMPLATE_ROOT_URI"
}

Write-Host
Write-Host "Using $buildingBlocksRootUriString to locate templates"
Write-Host

$templateRootUri = New-Object System.Uri -ArgumentList @($buildingBlocksRootUriString)

$virtualNetworkTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "/pierreroman/Igloo-POC/master/azuredeploy.json")
$virtualNetworkParametersFile = New-Object System.Uri -ArgumentList @($templateRootUri, "/pierreroman/Igloo-POC/master/parameters/virtualNetwork.parameters.json")
Write-Host
Write-Host "Template = '$virtualNetworkTemplate'"
Write-Host
Write-Host
Write-Host "Parameter file = '$virtualNetworkParametersFile'"
Write-Host



# Create the resource group
$networkResourceGroup = New-AzureRmResourceGroup -Name $networkResourceGroupName -Location $Location
Write-Host
Write-Host "Deploying virtual network..."
Write-Host
New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $networkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri -TemplateParameterFile $virtualNetworkParametersFile.AbsoluteUri -Force | Out-Null

# New-AzureRmResourceGroupDeployment -Name "vnet-deployment" -ResourceGroupName $networkResourceGroup.ResourceGroupName `
#    -TemplateFile C:\Users\pierrer\Documents\Github\Igloo-POC\vnet-subnet.json `
#    -TemplateParameterFile  C:\Users\pierrer\Documents\Github\Igloo-POC\vnet-subnet.parameters.json
