#Login-AzureRmAccount

$resourcegroup="igloo-POC-rg"
$location="east us 2"

$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
$Subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId | out-null

$Vmlist = Get-AzureRmVM -ResourceGroupName $resourcegroup



foreach ($vm in $Vmlist)
{
    if ($vm.StorageProfile.OsDisk.OsType -eq 'Windows')
    {
        $nics = get-azurermnetworkinterface

            foreach($nic in $nics)
            {
                $prv =  $nic.IpConfigurations | select-object -ExpandProperty PrivateIpAddress
            }

        Write-Host "$vm.Name $prv"

    }
}


