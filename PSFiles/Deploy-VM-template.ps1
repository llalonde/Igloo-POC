#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$VerbosePreference = "Continue"
$starttime = get-date


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

########################################################################################################################
# Key Vault and AAD variables
########################################################################################################################

# select Key Vault 
$keyVaultName = Read-Host -Prompt 'Input the Name of the KeyVault in which encryption keys are to be placed';

# select Azure AD App Name 
$aadAppName = Read-Host -Prompt 'Name of the AAD application that will be used to write secrets to KeyVault';
            
# select Key Vault encryption key 
$keyEncryptionKeyName = Read-Host -Prompt 'Name of optional key encryption key in KeyVault';


# Define a credential object
Write-Host "You Will now be asked for a UserName and Password that will be applied to the windows Virtual Machine that will be created";
$Wincred = Get-Credential 

# Define a credential object
Write-Host "You Will now be asked for a UserName and Password that will be applied to the linux Virtual Machine that will be created";
$Linuxcred = Get-Credential 
#endregion

#region Set Template and Parameter location

$Date = Get-Date -Format yyyyMMdd

# set  Root Uri of GitHub Repo (select AbsoluteUri)

$TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
$TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

$TemplateAS = $TemplateURI.AbsoluteUri + "VMTemplate-AS.json"
$Template = $TemplateURI.AbsoluteUri + "VMTemplate.json"

$domainToJoin = "iglooaz.local"

#endregion

#region Creation of Azure AD App and Key Vault

    ########################################################################################################################
    # Create AAD app . Fill in $aadClientSecret variable if AAD app was already created
    ########################################################################################################################


    # Check if AAD app with $aadAppName was already created
    $SvcPrincipals = (Get-AzureRmADServicePrincipal -SearchString $aadAppName);
    if(-not $SvcPrincipals)
    {
        # Create a new AD application if not created before
        $identifierUri = [string]::Format("http://localhost:8080/{0}",[Guid]::NewGuid().ToString("N"));
        $defaultHomePage = 'http://igloo.com';
        $now = [System.DateTime]::Now;
        $oneYearFromNow = $now.AddYears(1);
        $aadClientSecret = [Guid]::NewGuid();

        Write-Host "Creating new AAD application ($aadAppName)";
        $ADApp = New-AzureRmADApplication -DisplayName $aadAppName -HomePage $defaultHomePage -IdentifierUris $identifierUri  -StartDate $now -EndDate $oneYearFromNow -Password $aadClientSecret;
        $servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $ADApp.ApplicationId;
        $SvcPrincipals = (Get-AzureRmADServicePrincipal -SearchString $aadAppName);
        if(-not $SvcPrincipals)
        {
            # AAD app wasn't created 
            Write-Error "Failed to create AAD app $aadAppName. Please log-in to Azure using Login-AzureRmAccount  and try again";
            return;
        }
        $aadClientID = $servicePrincipal.ApplicationId;
        Write-Host "Created a new AAD Application ($aadAppName) with ID: $aadClientID ";
    }
    else
    {
        if(-not $aadClientSecret)
        {
            $aadClientSecret = Read-Host -Prompt "Aad application ($aadAppName) was already created, input corresponding aadClientSecret and hit ENTER. It can be retrieved from https://manage.windowsazure.com portal" ;
        }
        if(-not $aadClientSecret)
        {
            Write-Error "Aad application ($aadAppName) was already created. Re-run the script by supplying aadClientSecret parameter with corresponding secret from https://manage.windowsazure.com portal";
            return;
        }
        $aadClientID = $SvcPrincipals[0].ApplicationId;
    }
    
    ########################################################################################################################
    # Create KeyVault or setup existing keyVault
    ########################################################################################################################

    Try
    {
        $resGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue;
    }
    Catch [System.ArgumentException]
    {
        Write-Host "Couldn't find resource group:  ($resourceGroupName)";
        $resGroup = $null;
    }
    
    #Create a new resource group if it doesn't exist
    if (-not $resGroup)
    {
        Write-Host "Creating new resource group:  ($resourceGroupName)";
        $resGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $location;
        Write-Host "Created a new resource group named $resourceGroupName to place keyVault";
    }
    
    Try
    {
        $keyVault = Get-AzureRmKeyVault -VaultName $keyVaultName -ErrorAction SilentlyContinue;
    }
    Catch [System.ArgumentException]
    {
        Write-Host "Couldn't find Key Vault: $keyVaultName";
        $keyVault = $null;
    }
    
    #Create a new vault if vault doesn't exist
    if (-not $keyVault)
    {
        Write-Host "Creating new key vault:  ($keyVaultName)";
        $keyVault = New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Sku Standard -Location $location;
        Write-Host "Created a new KeyVault named $keyVaultName to store encryption keys";
    }
    # Specify privileges to the vault for the AAD application - https://msdn.microsoft.com/en-us/library/mt603625.aspx
    Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ServicePrincipalName $aadClientID -PermissionsToKeys all -PermissionsToSecrets all;

    Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -EnabledForDiskEncryption;

    $diskEncryptionKeyVaultUrl = $keyVault.VaultUri;
	$keyVaultResourceId = $keyVault.ResourceId;


    if($keyEncryptionKeyName)
    {
        Try
        {
            $kek = Get-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyEncryptionKeyName -ErrorAction SilentlyContinue;
        }
        Catch [Microsoft.Azure.KeyVault.KeyVaultClientException]
        {
            Write-Host "Couldn't find key encryption key named : $keyEncryptionKeyName in Key Vault: $keyVaultName";
            $kek = $null;
        } 

        if(-not $kek)
        {
            Write-Host "Creating new key encryption key named:$keyEncryptionKeyName in Key Vault: $keyVaultName";
            $kek = Add-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyEncryptionKeyName -Destination Software -ErrorAction SilentlyContinue;
            Write-Host "Created  key encryption key named:$keyEncryptionKeyName in Key Vault: $keyVaultName";
        }

        $keyEncryptionKeyUrl = $kek.Key.Kid;
    }   

    ########################################################################################################################
    # Displays values that should be used while enabling encryption. 
    ########################################################################################################################
    Write-Host "Please note down below aadClientID, aadClientSecret, diskEncryptionKeyVaultUrl, keyVaultResourceId values that will be needed to enable encryption on your VMs " -foregroundcolor Green;
    Write-Host "`t aadClientID: $aadClientID" -foregroundcolor Green;
    Write-Host "`t aadClientSecret: $aadClientSecret" -foregroundcolor Green;
    Write-Host "`t diskEncryptionKeyVaultUrl: $diskEncryptionKeyVaultUrl" -foregroundcolor Green;
    Write-Host "`t keyVaultResourceId: $keyVaultResourceId" -foregroundcolor Green;
    if($keyEncryptionKeyName)
    {
        Write-Host "`t keyEncryptionKeyURL: $keyEncryptionKeyUrl" -foregroundcolor Green;
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
    $DataDiskName = $VM.ServerName + "Data"
    $VMImageName = $vm.ImageName
    $Nic = $VMName + '-nic'
   
    switch ($VMOS) {
        "Linux" {$cred = $Linuxcred}
        "Windows" {$cred = $Wincred}
        Default {Write-Host "No OS Defined...."}
    }

    $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName
    $vnetname = $vnet.Name
    
    Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName -ev notPresent -ea 0 | out-null

    if ($notPresent) {
        Write-Output "Deploying $VMOS VM named '$VMName'..."
        $DeploymentName = 'VM-' + $VMName + '-' + $Date

        if ($ASname -eq "None") {
            New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $Template -TemplateParameterObject `
            @{ `
                    virtualMachineName            = $VMName; `
                    virtualMachineSize            = $VMSize; `
                    adminUsername                 = $cred.UserName; `
                    virtualNetworkName            = $vnetname; `
                    networkInterfaceName          = $Nic; `
                    adminPassword                 = $cred.Password; `
                    diagnosticsStorageAccountName = 'logsa2osxahd4fkgbq'; `
                    subnetName                    = $VMsubnet; `
                    ImageURI                      = $VMImageName; `
                    
            
            } -Force | out-null 

            

        }
        else {
            New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateAS -TemplateParameterObject `
            @{ `
                    virtualMachineName            = $VMName; `
                    virtualMachineSize            = $VMSize; `
                    adminUsername                 = $cred.UserName; `
                    virtualNetworkName            = $vnetname; `
                    networkInterfaceName          = $Nic; `
                    adminPassword                 = $cred.Password; `
                    availabilitySetName           = $ASname.ToLower(); `
                    diagnosticsStorageAccountName = 'logsa2osxahd4fkgbq'; `
                    subnetName                    = $VMsubnet; `
                    ImageURI                      = $VMImageName; `
            
            } -Force | out-null             

        } 

        if ($VMDataDiskSize -ne "None") {
            Write-Output "     Adding Data Disk to '$VMName'..."
            $storageType = 'StandardLRS'
            $dataDiskName = $VMName + '_datadisk1'

            $diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Empty -DiskSizeGB $VMDataDiskSize
            $dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $ResourceGroupName
            $VMdiskAdd = Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName 
            $VMdiskAdd = Add-AzureRmVMDataDisk -VM $VMdiskAdd -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1
            Update-AzureRmVM -VM $VMdiskAdd -ResourceGroupName $ResourceGroupName | out-null            
        }
        
        
        if ($VMOS -eq "Windows") {
            Write-Output "     Joining '$VMName' to '$domainToJoin'..."
            $domainAdminUser = $domainToJoin + "\" + $cred.UserName.ToString()
            $domPassword = $cred.GetNetworkCredential().Password
            $DomainJoinPassword = $cred.Password

            $Results = Set-AzureRMVMExtension -VMName $VMName -ResourceGroupName $ResourceGroupName `
                -Name "JoinAD" `
                -ExtensionType "JsonADDomainExtension" `
                -Publisher "Microsoft.Compute" `
                -TypeHandlerVersion "1.3" `
                -Location $Location.ToString() `
                -Settings @{ "Name" = $domainToJoin.ToString(); "User" = $domainAdminUser.ToString(); "Restart" = "true"; "Options" = 3} `
                -ProtectedSettings @{"Password" = $domPassword}
        
            if ($Results.StatusCode -eq "OK") {
                Write-Output "     Successfully joined domain '$domainToJoin.ToString()'..."
            }
            Else {
                Write-Output "     Failled to join domain '$domainToJoin.ToString()'..."
            }
        }            
    }
    else {
        Write-Output "Virtual Machine '$VMName' already exist and will be skipped..."
    }

    # Try setting volume type to Data only for Linux and All for Windows to see if that resolves issues on encrypting disks on Linux
    #$volumeType = "Data"

    #if ($VMOS -eq "Windows") {
        $volumeType = "All"           
    #} 
    
    Write-Output "Encrypting $volumeType disk(s) on '$VMName'..."

    Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
            -AadClientID $aadClientID -AadClientSecret $aadClientSecret `
            -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId `
            -VolumeType $volumeType -Force –SkipVmBackup

    # View encryption status
    Get-AzureRmVmDiskEncryptionStatus  -ResourceGroupName $ResourceGroupName -VMName $VMName
    
}

#endregion
