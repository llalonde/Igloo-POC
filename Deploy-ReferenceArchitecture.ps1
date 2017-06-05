#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

#region Prep & signin

# sign in
Write-Host "Logging in ...";
#Login-AzureRmAccount | Out-Null

# select subscription
$subscriptionId = Read-Host -Prompt 'Input your Subscription ID'
Write-Host 
Write-Host "Connecting to subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId | Out-Null
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

# Templates for the deploment (include filename)
# $VMListfile= $TemplateURI.AbsoluteUri + "VMList.csv"


$VnetTemplate = $TemplateURI.AbsoluteUri + "vnet-subnet.json"
$ASATemplate = $TemplateURI.AbsoluteUri + "ASA.json"
$StorageTemplate = $TemplateURI.AbsoluteUri + "VMStorageAccount.json"


#Parameter files for the deployment (include relative path to repo + filename)

$VnetParametersFile = $TemplateURI.AbsoluteUri + "parameters/vnet-subnet.parameters.json"
$ASAParametersFile = $TemplateURI.AbsoluteUri + "parameters/asa.parameters.json"
$StorageParametersFile = $TemplateURI.AbsoluteUri + "parameters/VMStorageAccount.parameters.json"




#endregion


#region Create the resource group

Get-AzureRmResourceGroup -Name $ResourceGroupName -ev notPresent -ea 0  | Out-Null

if ($notPresent) {
    Write-Host
    Write-Host 
    Write-Output "Could not find resource group '$ResourceGroupName' - will create it."
    Write-Host 
    Write-Host
    Write-Output "Creating resource group '$ResourceGroupName' in location '$Location'...."
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Force | Out-Null

}
else {
    Write-Host
    Write-Host 
    Write-Output "Using existing resource group '$ResourceGroupName'"
}

#endregion


# Start the deployment
Write-Host 
Write-Host 
Write-Output "Starting deployment"

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

    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -TemplateParameterUri $VnetParametersFile -Force | Out-Null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Mode Complete -Name "vnet-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $VnetTemplate -Force | Out-Null

}

#endregion


#region Deploy Cisco ASA appliance 
Write-Host 
Write-Output "Deploying Cisco ASAv appliance..."

$ASAResourceGroupName = $ResourceGroupName + "-ASA"

Get-AzureRmResourceGroup -Name $ASAResourceGroupName -ev notPresent -ea 0 | Out-Null

if ($notPresent) {
    Write-Host 
    Write-Host 
    Write-Output "Could not find resource group '$ASAResourceGroupName' - will create it"
    Write-Host 
    Write-Host 
    Write-Output "Creating resource group '$ASAResourceGroupName' in location '$Location'...."
    New-AzureRmResourceGroup -Name $ASAResourceGroupName -Location $Location -Force | Out-Null

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
    New-AzureRmResourceGroupDeployment -Name "ASA-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -TemplateParameterUri $ASAParametersFile -Force | Out-Null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Name "ASA-deployment" -ResourceGroupName $ASAResourceGroupName -TemplateUri $ASATemplate -Force | Out-Null

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

    New-AzureRmResourceGroupDeployment -Name "Storage-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $StorageTemplate -TemplateParameterUri $StorageParametersFile -Force | Out-Null
}
else {
    Write-Host 
    Write-Host 
    write-host "The parameter file was not found, you will need to enter all parameters manually...."
    write-host
    New-AzureRmResourceGroupDeployment -Name "Storage-deployment" -ResourceGroupName $ResourceGroupName -TemplateUri $StorageTemplate -Force | Out-Null

}

#endregion


#region Read in List of VM to create

Write-Host 
Write-Host 
Write-Host "Read in list of VM to Create...."
 
$VMList = Import-CSV $VMListfile 
 
$Counter = 1
 
foreach ($VM in $VMList) {
    $Counter++

    $VMName = $VM.ServerName

    Write-Host "Processing '$VMName'"
    Write-Host

    # Create a public IP address and specify a DNS name
    Write-Host
    Write-Host "Create a public IP address and a DNS name"
    $pip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $location -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name $VMName -Force | Out-Null
    $vnet = Get-AzureRMVirtualNetwork
    $Subnets = $vnet.Subnets
    
    Write-Host "Create a Network Interface Card for the VM"
    Write-Host 

    foreach ($Items in $Subnets)
        {
            $subnetname = $Items.Name
            if ($subnetname -eq $vm.subnet)
            {
                $subnetID = $Items.Id
                $PipID = $pip.Id
                $nic = New-AzureRmNetworkInterface -Name $VMName -ResourceGroupName $ResourceGroupName -Location $location -SubnetId $subnetID -PublicIpAddressId $PipID
                $nicID = $nic.Id
            }
        }
    # Create a virtual machine configuration


    if ($vm.OS -eq "Windows")
    {
        Write-Host "Creating Windows Virtual Machine '$VMName' ...."
        Write-Host 
        Write-Host 

        $StorageAccount = Get-AzureRmStorageAccount -Name $vm.StorageAccount -ResourceGroupName $ResourceGroupName
        $OSDiskName = $VMName + "OSDisk"

        $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $vm.VMSize
        $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Cred -ProvisionVMAgent -EnableAutoUpdate
        $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"
        $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nicID
        $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
        $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

        New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine
 

        #$vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $vm.VMSize | `
        #            Set-AzureRmVMOperatingSystem -Windows -ComputerName $vm.ServerName -Credential $cred | `
        #            Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version latest | Add-AzureRmVMNetworkInterface -Id $nic.Id

        #New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $location -VM $VirtualMachine
    }
    else
    {
        Write-Host "Creating Linux Virtual Machine '$VMName' ...."
        Write-Host 
        Write-Host 

        $StorageAccount = Get-AzureRmStorageAccount -Name $vm.StorageAccount -ResourceGroupName $ResourceGroupName
        $OSDiskName = $VMName + "OSDisk"

        $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $vm.VMSize
        $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $VM.ServerName -Credential $cred
        $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName Canonical -Offer UbuntuServer -Skus 14.04.2-LTS -Version latest
        $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nicID
        $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
        $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

        New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine

        
        #$vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $vm.VMSize | `
        #    Set-AzureRmVMOperatingSystem -Linux -ComputerName $VM.ServerName -Credential $cred | `
        #     Set-AzureRmVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 14.04.2-LTS -Version latest | `
        #    Add-AzureRmVMNetworkInterface -Id $nic.Id

        #New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $location -VM $vmConfig
    }

    
}
Write-Host " '$counter' VM in the list"

#endregion



if ($error.Count -eq 0) {
    Write-Host 
    Write-Host 
    Write-Host "Deployment of Architecture failed"
}
else {
    Write-Host 
    Write-Host 
    Write-Host "Deployment of Architecture succeeded"
}
