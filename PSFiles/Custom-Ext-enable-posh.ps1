$cred=Get-Credential
$script = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/PSFiles/enable-posh-remote.ps1"
$run="enable-posh-remote.ps1"
$name="custom-script"
$resourcegroup="igloo-POC-rg"
$location="east us 2"
Login-AzureRmAccount -Credential $cred
$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
$Subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId | out-null

$Vmlist = Get-AzureRmVM

foreach ($vm in $Vmlist)
{
    $vmname = $vm.Name
    Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourcegroup -VMName $vmname -Name $name -FileUri $script -Run $run -Location $location

    Get-AzureRmVMCustomScriptExtension -ResourceGroupName $resourcegroup -VMName $vmname -Name $name
}


