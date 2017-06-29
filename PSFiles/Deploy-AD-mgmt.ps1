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

# Define a credential object
$cred = Get-Credential -Message "UserName and Password for Windows VM"

#endregion

#region Set Template and Parameter location

$Date=Get-Date -Format yyyyMMdd

# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

$DCTemplate = $TemplateURI.AbsoluteUri + "AD-2DC.json"

#endregion

#region Deployment of DC
Write-Output "Deploying New Domain with Controllers..."
$DeploymentName = 'Domain-DC-'+ $Date

$userName=$cred.UserName
$password=$cred.GetNetworkCredential().Password

New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $$DCTemplate -TemplateParameterObject `
    @{ `
        adVMName = 'poc-eus-dc1'; `
        storageAccountName = 'igloostoragestdpoc'
        adminUsername = $userName; `
        adminPassword = $password; `
        domainName = 'Iglooaz.local'
        adAvailabilitySetName = 'Igloo-POC-DC-AS'; `
        virtualNetworkName = 'Vnet-Igloo-POC'; `
    } -Force | out-null

#endregion




$endtime = get-date
$procestime = $endtime - $starttime
$time = "{00:00:00}" -f $procestime.Minutes
write-host " Deployment completed in '$time' "









