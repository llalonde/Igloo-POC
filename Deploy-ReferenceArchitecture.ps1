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
#region Set Template and Parameter location

# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

$VnetTemplate = $TemplateURI.AbsoluteUri + "vnet-subnet.json"
$ASATemplate = $TemplateURI.AbsoluteUri + "ASA.json"
$StorageTemplate = $TemplateURI.AbsoluteUri + "VMStorageAccount.json"

#Parameter files for the deployment (include relative path to repo + filename)

$VnetParametersFile = $TemplateURI.AbsoluteUri + "parameters/vnet-subnet.parameters.json"
$ASAParametersFile = $TemplateURI.AbsoluteUri + "parameters/asa.parameters.json"
$StorageParametersFile = $TemplateURI.AbsoluteUri + "parameters/VMStorageAccount.parameters.json"

#endregion
#region Create the resource group

# Start the deployment
Write-Host 
Write-Host 
Write-Output "Starting deployment"

Get-AzureRmResourceGroup -Name $ResourceGroupName -ev notPresent -ea 0  | Out-Null

if ($notPresent) {
    Write-Output "Could not find resource group '$ResourceGroupName' - will create it."
    Write-Output "Creating resource group '$ResourceGroupName' in location '$Location'...."
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Force | out-null

}
else {
    Write-Output "Using existing resource group '$ResourceGroupName'"
}

#endregion
#region Deployment of virtual network
Write-Host 
Write-Host 
Write-Output "Deploying virtual network..."

if (Invoke-WebRequest -Uri $VnetParametersFile) {
    Write-Host 
    Write-Host 
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$VnetTemplate'"
    write-host " Parameter file:    '$VnetParametersFile'"
    write-host

    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -TemplateParameterUri $VnetParametersFile -Force | out-null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -Force | out-null

}

#endregion
#region Deploy Cisco ASA appliance 
Write-Host 
Write-Output "Deploying Cisco ASAv appliance..."

$ASAResourceGroupName = $ResourceGroupName + "-ASA"

Get-AzureRmResourceGroup -Name $ASAResourceGroupName -ev notPresent -ea 0 | out-null

if ($notPresent) {
    Write-Host 
    Write-Host 
    Write-Output "Could not find resource group '$ASAResourceGroupName' - will create it"
    Write-Host 
    Write-Host 
    Write-Output "Creating resource group '$ASAResourceGroupName' in location '$Location'...."
    New-AzureRmResourceGroup -Name $ASAResourceGroupName -Location $Location -Force | out-null

}
else {
    Write-Host 
    Write-Host 
    Write-Output "Using existing resource group '$ASAResourceGroupName'"
}

if (Invoke-WebRequest -Uri $ASAParametersFile) {
    Write-Host 
    Write-Host 
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$ASATemplate'"
    write-host " Parameter file:    '$ASAParametersFile'"
    write-host
    New-AzureRmResourceGroupDeployment -Name "ASA-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -TemplateParameterUri $ASAParametersFile -Force | out-null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Name "ASA-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -Force | out-null

}

#endregion
#region Deployment of Storage Account
Write-Host 
Write-Host 
Write-Output "Deploying Storage Accounts..."

if (Invoke-WebRequest -Uri $StorageParametersFile) {
    Write-Host 
    Write-Host 
    write-host "The parameter file was found, we will use the following info: "
    write-host " Template file:     '$StorageTemplate'"
    write-host " Parameter file:    '$StorageParametersFile'"
    write-host

    New-AzureRmResourceGroupDeployment -Name "Storage-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $StorageTemplate -TemplateParameterUri $StorageParametersFile -Force | out-null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Name "Storage-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $StorageTemplate -Force | out-null

}

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

$endtime = get-date
$procestime = $endtime - $starttime

write-host " Deployment completed in '$procestime'"
