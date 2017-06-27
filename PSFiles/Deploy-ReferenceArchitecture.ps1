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

# Define a credential object
$cred = Get-Credential -Message "UserName and Password for Windows VM"

# Define a credential object
$Linuxcred = Get-Credential -Message "UserName and Password for Linux VM"


#endregion


#region Set Template and Parameter location

$Date=Get-Date -Format yyyyMMdd

# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

$VnetTemplate = $TemplateURI.AbsoluteUri + "vnet-subnet.json"
$DCTemplate = $TemplateURI.AbsoluteUri + "DC.json"
$StorageTemplate = $TemplateURI.AbsoluteUri + "VMStorageAccount.json"
$ASTemplate = $TemplateURI.AbsoluteUri + "AvailabilitySet.json"
#$NSGTemplate = $TemplateURI.AbsoluteUri + "nsg.azuredeploy.json"

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
$DeploymentName = 'Vnet-Subnet-'+ $Date
New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -TemplateParameterObject `
    @{ `
        vnetname='Vnet-Igloo-POC'; `
        VnetaddressPrefix = '192.168.0.0/17'; `
        mgmtsubnetsname = 'mgmt'; `
        mgmtsubnetaddressPrefix = '192.168.105.0/24'; `
        publicdmzinsubnetsname = 'Inside'; `
        publicdmzinsubnetaddressPrefix = '192.168.114.0/24'; `
        publicdmzoutsubnetsname = 'Outside'; `
        publicdmzoutsubnetaddressPrefix = '192.168.113.0/24'; `
        websubnetsname = 'web'; `
        websubnetaddressPrefix = '192.168.115.0/24'; `
        bizsubnetsname = 'biz';`
        bizsubnetaddressPrefix = '192.168.116.0/24'; `
        datasubnetsname = 'data';`
        datasubnetaddressPrefix = '192.168.102.0/24'; `
        Gatewaysubnetsname = 'GatewaySubnet'; `
        GatewaysubnetaddressPrefix = '192.168.127.0/24'; `
    } -Force | out-null

#endregion

#region Deployment of Storage Account
Write-Output "Deploying Storage Accounts..."
$DeploymentName = 'storageAccount'+ $Date
New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $StorageTemplate -TemplateParameterObject `
    @{ `
        stdname = 'igloostdstore'; `
        premname = 'igloopremstore'; `
    } -Force | out-null

#endregion

#region Deployment of Availability Sets
$ASList = Import-CSV $VMListfile | Where-Object {$_.AvailabilitySet -ne "None"}
$ASListUnique = $ASList.AvailabilitySet | select-object -unique

ForEach ( $AS in $ASListUnique)
{
    $ASName=$AS
    $DeploymentName = $AS + $Date
    New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $ASTemplate -TemplateParameterObject `
        @{ AvailabilitySetName = $ASName.ToString() ; `
            faultDomains = 2 ; `
            updateDomains = 5 ; `
        } -Force | out-null
}
#endregion

#region Deployment of NSG

$NSGList = Import-CSV $VMListfile
$NSGListUnique = $NSGList.subnet | select-object -unique

ForEach ( $NSG in $NSGListUnique){
    $NSGName=$NSG+"-nsg"
    $DeploymentName = $AS + $Date
    New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $NSGTemplate -TemplateParameterObject `
        @{`
            networkSecurityGroupName=$NSGName.ToString(); `
         } -Force | out-null
}
#endregion

#region Deployment of domain controler
$DeploymentName = "Domain" + $Date

$adminPassword = $cred.password
$adminUsername = $cred.Username

New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $DCTemplate -TemplateParameterObject `
    @{`
        virtualMachineName='poc-eus-dc1'; `
        virtualMachineSize='Standard_D2_v2'; `
        adminUsername=$adminUsername.ToString(); `
        virtualNetworkName='Vnet-Igloo-POC'; `
        networkInterfaceName='poc-eus-dc1'; `
        adminPassword=$adminPassword
        domainName='iglooaz.local'; `
        diagnosticsStorageAccountName='igloostdstore'; `
        subnetName='mgmt'; `
    } -Force | out-null

#endregion


$endtime = get-date
$procestime = $endtime - $starttime
$time = "{00:00:00}" -f $procestime.Minutes
write-host " Deployment completed in '$time' "









