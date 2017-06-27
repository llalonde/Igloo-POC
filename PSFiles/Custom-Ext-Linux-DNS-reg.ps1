Login-AzureRmAccount

$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
$Subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId | out-null


#$script = '{"fileUris": ["https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/Custom_Scripts/dnsupdate.sh"],"commandToExecute": "./dnsupdate.sh"}'
$run="sh dnsupdate.sh"
$name="customScript"
$resourcegroup="igloo-POC-rg"
$location="east us 2"

$Vmlist = Get-AzureRmVM -ResourceGroupName $resourcegroup

foreach ($vm in ($Vmlist | where{$_.StorageProfile.OsDisk.OsType -eq 'Linux'}))
{
    $vmname = $vm.Name.tostring()
    Write-Output $vmname
    #Get-AzureRmVMExtension -Name $name -ResourceGroupName $resourcegroup -VMName $vmname -Status
    #Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourcegroup -VMName $vmname -Name $name -FileUri $script -Run $run -Location $location
    az vm extension set --resource-group $resourcegroup --vm-name $vmname --name customScript --publisher Microsoft.Azure.Extensions --settings 
}