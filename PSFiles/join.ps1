Write-Host "Logging in ...";
Login-AzureRmAccount | Out-Null

# select subscription
$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
$Subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId | out-null

# select Resource Group
$ResourceGroupName = Read-Host -Prompt 'Input the resource group for your network'

$MyCreds = Get-Credential

$ADaccount = Get-Credential

$Vmlist = Get-AzureRmVM


foreach ($vm in $Vmlist)
{
    if ($vm.StorageProfile.OsDisk.OsType -eq 'Windows')
    {
      Write-Host $vm.Name
      Invoke-Command -ComputerName $vm.Name -Credential $MyCreds { `
      Add-Computer -Credential $ADaccount -DomainName iglooaz -ComputerName $vm.Name -LocalCredential $MyCreds -Restart `
      }
    }
   
}
