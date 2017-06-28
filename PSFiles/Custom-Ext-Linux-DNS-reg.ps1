Login-AzureRmAccount

$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
$Subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId | out-null

$resourcegroup="igloo-POC-rg"
$location="east us 2"

$Vmlist = Get-AzureRmVM -ResourceGroupName $resourcegroup

foreach ($vm in ($Vmlist | where{$_.StorageProfile.OsDisk.OsType -eq 'Linux'}))
{
    $vmname = $vm.Name.tostring()
    Write-Output $vmname
    az vm extension set --resource-group $resourcegroup --vm-name $vmname --name customScript --publisher Microsoft.Azure.Extensions --settings C:\Users\pierrer\Documents\Github\Igloo-POC\Custom_Scripts\linux-dns.json
}