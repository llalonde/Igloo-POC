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

ForEach ( $VM in $VMList) {
    $VMName = $VM.ServerName
    $ASname = $VM.AvailabilitySet
    $VMsubnet = $VM.subnet
    $VMOS = $VM.OS
    $VMStorage = $vm.StorageAccount
    $VMSize = $vm.VMSize
    $VMDataDiskSize = $vm.DataDiskSize
    
    Write-Host "Processing '$VMName'...."

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
        
        New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine
               
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