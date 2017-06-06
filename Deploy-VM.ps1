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
Write-Host 
Write-Host "Connecting to subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId | out-null
Write-Host 

# select Resource Group
$ResourceGroupName = Read-Host -Prompt 'Input the resource group for your network'
Write-Host 
Write-Host "Selecting Resource Group '$ResourceGroupName'";
Write-Host 

# select Location
$Location = Read-Host -Prompt 'Input the Location for your network'
Write-Host 
Write-Host "Setting location as '$Location'";
Write-Host 

# select Location
$VMListfile = Read-Host -Prompt 'Input the Location of the list of VMs to be created'
Write-Host 
Write-Host

# Define a credential object
Write-Host "You Will now be asked for a UserName and Password that will be applied to all the Virtual Machine that will be created";
$cred = Get-Credential 

#endregion

#region Deployment of VM from VMlist.CSV
$VMList = Import-CSV $VMListfile
ForEach ( $VM in $VMList) {
    $VMName = $VM.ServerName
    $ASname = $VM.AvailabilitySet
    $VMsubnet = $VM.subnet
    $VMOS = $VM.OS
    $VMStorage = $vm.StorageAccount
    $VMSize = $vm.VMSize
    $VMDataDiskSize = $vm.DataDiskSize
    
    Write-Host "Processing '$VMName'...."
      
    if ($ASname -ne "None") {
        Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -name $ASname -ev notPresent -ea 0  | Out-Null
        if ($notPresent) {
            Write-Output "Could not find Availability Set '$ASname'in '$ResourceGroupName' - It will be created."
            Write-Output "Creating Availability Set '$ASname'...."
            Write-host 
            New-AzureRmAvailabilitySet -Location $Location -Name $ASname -ResourceGroupName $ResourceGroupName | out-null
            $AS=Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -name $ASname
            $ASID=$as.Id
        }
        else {
            Write-Output "Using existing Availability Set '$ASname'...."
            Write-host 
            $AS=Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -name $ASname
            $ASID=$as.Id
        }
    }
    else{
        write-host "Vistual Machine not part of an availability set"
    }
   
    $vnet = Get-AzureRMVirtualNetwork
    $Subnets = $vnet.Subnets
    
    foreach ($Items in $Subnets) {
        $subnetname = $Items.Name
        if ($subnetname -eq $VMsubnet) {
            $subnetID = $Items.Id
            $nic = New-AzureRmNetworkInterface -Name $VMName -ResourceGroupName $ResourceGroupName -Location $location -SubnetId $subnetID -Force
            $nicID = $nic.Id
        }
    }

    if ($VMOS -eq "Windows") {
        $StorageAccount = Get-AzureRmStorageAccount -Name $VMStorage -ResourceGroupName $ResourceGroupName
        $OSDiskName = $VMName + "OSDisk"
        if ($ASname -eq "None") {
            $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
        }
        else {
            Write-Host "Adding '$VMName' to '$ASname'...."
            $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetID $ASID
        }
        $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Cred -ProvisionVMAgent -EnableAutoUpdate
        $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"
        $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nicID
        $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
        $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage
        New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine | out-null
        if ($VMDataDiskSize -ne "none") {
            $DATADiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $DataDiskName + ".vhd"
            $Myvm = Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName
            Add-AzureRmVMDataDisk -VM $VirtualMachine -Name $Myvm -VhdUri $DATADiskUri -LUN 0 -Caching ReadOnly -DiskSizeinGB $VMDataDiskSize -CreateOption Empty | out-null
            Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $Myvm
            }
      }
    else {
        $StorageAccount = Get-AzureRmStorageAccount -Name $VMStorage -ResourceGroupName $ResourceGroupName
        $OSDiskName = $VMName + "OSDisk"
        if ($ASname -eq "None") {
            $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
        }
        else {
            Write-Host "Adding Virtual Machine '$VMName' to Availability Set '$ASname'...."
            Write-host 
            $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetID $ASId
        }
        $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $VMName -Credential $cred
        $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName Canonical -Offer UbuntuServer -Skus 14.04.2-LTS -Version latest
        $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nicID
        $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
        $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage
        New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine
        if ($VMDataDiskSize -ne "none") {
            $DataDiskName = $VMName + "DataDisk"
            $DATADiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $DataDiskName + ".vhd"
            $Myvm = Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName
            Add-AzureRmVMDataDisk -VM $Myvm -Name $DataDiskName -VhdUri $DATADiskUri -LUN 0 -Caching ReadOnly -DiskSizeinGB $VMDataDiskSize -CreateOption Empty | out-null
            Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $Myvm
        }
    }
}
#endregion