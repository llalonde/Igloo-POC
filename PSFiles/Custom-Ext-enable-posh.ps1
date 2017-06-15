Login-AzureRmAccount

$script = "https://poceussmb1.blob.core.windows.net/scripts/enable-posh-remote.ps1"
$run="enable-posh-remote.ps1"
$name="custom-script"
$resourcegroup="igloo-POC-rg"
$location="east us 2"

$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
$Subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId | out-null

$Vmlist = Get-AzureRmVM -ResourceGroupName $resourcegroup

foreach ($vm in $Vmlist)
{
    if ($vm.StorageProfile.OsDisk.OsType -eq 'Windows')
    {
        $vmname = $vm.Name
        Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourcegroup -VMName $vmname -Name $name -FileUri $script -Run $run -Location $location

        Get-AzureRmVMCustomScriptExtension -ResourceGroupName $resourcegroup -VMName $vmname -Name $name

    }
}


