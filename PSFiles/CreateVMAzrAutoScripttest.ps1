workflow CreateVMfromCSV {
    sequence {
        $servicePrincipalConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'
    		
        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint   $servicePrincipalConnection.CertificateThumbprint 
		
        $ErrorActionPreference = "Stop"
        $WarningPreference = "SilentlyContinue"
		
        # set  Root Uri of GitHub Repo (select AbsoluteUri)

        $VMListRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
        $VMListRootURI = New-Object System.Uri -ArgumentList @($VMListRootUriString)

        $VMListURI = $VMListRootURI.AbsoluteUri + "csv_files/VMList.csv"

        $source = $VMListURI
        $destination = "c:\csv_files\VMList.csv"
        "Dowloading CSV file to Azure Automation Instance..."
        Invoke-WebRequest $source -OutFile $destination

        $VMList = import-csv $destination

        #region Set Template and Parameter location
        # set  Root Uri of GitHub Repo (select AbsoluteUri)

        $TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
        $TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

        $VMTemplate = $TemplateURI.AbsoluteUri + "WindowsVMfromImage.json"

        #region Deployment of VMs

        $VMList = Import-CSV $VMListfile | Where-Object {$_.OS -eq "Windows"}

        ForEach -parallel($VM in $VMList) {
            New-AzureRmResourceGroupDeployment -Name $vm.servername -ResourceGroupName $ResourceGroupName -TemplateUri $VMTemplate -TemplateParameterObject `
            @{
                virtualMachineName = $vm.servername ; 
                virtualMachineSize = $vm.VMSize ; 
                adminUsername = $cred.GetNetworkCredential().Username ; `
                networkInterfaceName = $vm.servername + '-nic'; `
                adminPassword = $cred.GetNetworkCredential().Password ; 
                diagnosticsStorageAccountName = $vm.StorageAccount ; `
                subnetName = $vm.subnet ; `
                availabilitySetName = $vm.AvailabilitySet ; `
            }
        }
    }
}