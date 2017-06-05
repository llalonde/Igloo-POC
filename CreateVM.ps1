$StartExecutionTime = Get-Date 
 
&quot;Script Started...&quot;
 
Import-Module -Name Azure
 
$VMList = Import-CSV C:\VMListWindows.csv 
 
 
 
$Counter = 1
 
foreach ($VM in $VMList)
{
 
 
## set the current storage account
Set-AzureSubscription -SubscriptionName $vm.subscription -CurrentStorageAccountName $vm.storageaccount
 
New-AzureService -ServiceName $vm.cloudservice -AffinityGroup $vm.affinitygroup
 
 
$vmconfig = New-AzureVMConfig -Name $vm.vmname -InstanceSize $vm.InstanceSize -ImageName $vm.imagename | Add-AzureProvisioningConfig -AdminUsername &quot;MSAzureAdmin&quot;  -Windows -DisableGuestAgent -Password &quot;pass@word1&quot; | Set-AzureSubnet -SubnetNames $vm.subnet | Set-AzureStaticVNetIP -IPAddress $vm.vmipaddress  | New-AzureVM  -ServiceName $vm.cloudservice -VNetName $vm.vnetname -WaitForBoot
 
$Counter++
}
 
&quot;Done...&quot;
 
 
 
$EndExecutionTime = Get-Date
 
$TotalExecutionTime =  $EndExecutionTime - $StartExecutionTime
 
&quot;Total Execution Time: &quot; + &quot;{0:N0}&quot; -f $TotalExecutionTime.TotalMinutes + &quot; Minute(s)&quot;
