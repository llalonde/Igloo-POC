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

# Get Credentials for the VM
$cred = Get-Credential -Message 'Type the local administrator account username and password:'

#endregion

#region Set Template and Parameter location
# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

$VMTemplate = $TemplateURI.AbsoluteUri + "WindowsVMfromImage.json"

#region Deployment of VMs

$VMList = Import-CSV $VMListfile | Where-Object {$_.OS -eq "Windows"}

ForEach ( $VM in $VMList)
{
    Write-Host $vm.servername
    New-AzureRmResourceGroupDeployment -Name $vm.servername -ResourceGroupName $ResourceGroupName -TemplateUri $VMTemplate -TemplateParameterObject `
    @{
        virtualMachineName = $vm.servername ; 
        virtualMachineSize = $vm.VMSize ; 
        adminUsername = $cred.GetNetworkCredential().Username ; `
        networkInterfaceName = $vm.servername+'-nic'; `
        adminPassword = $cred.GetNetworkCredential().Password ; 
        diagnosticsStorageAccountName = $vm.StorageAccount ; `
        subnetName = $vm.subnet ; `
        availabilitySetName = $vm.AvailabilitySet ; `
    } -Force | out-null
}