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

        "set Resource Group..."
        $ResourceGroupName= "Igloo-POC-rg"
		
        "set  Root Uri of GitHub Repo..."

        $VMListRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
        $VMListRootURI = New-Object System.Uri -ArgumentList @($VMListRootUriString)

        $VMListURI = $VMListRootURI.AbsoluteUri + "csv_files/VMList.csv"

        $source = $VMListURI
        $destination = "$env:userprofile\downloads\VMList.csv"

        "downloading from '$source' to '$destination' ..."

        "Dowloading CSV file to Azure Automation Instance..."
        Invoke-WebRequest $source -OutFile $destination

        $VMList = import-csv $destination

        #region Set Template and Parameter location
        # set  Root Uri of GitHub Repo (select AbsoluteUri)

        $TemplateRootUriString = "https://raw.githubusercontent.com/pierreroman/Igloo-POC/master/"
        $TemplateURI = New-Object System.Uri -ArgumentList @($TemplateRootUriString)

        $VMTemplate = $TemplateURI.AbsoluteUri + "WindowsVMfromImage.json"

        #region Deployment of VMs

        $VMList = Import-CSV $destination | Where-Object {$_.OS -eq "Windows"}

        ForEach -parallel($VM in $VMList) {
            New-AzureRmResourceGroupDeployment -Name $vm.servername -ResourceGroupName $ResourceGroupName -TemplateUri $VMTemplate -TemplateParameterObject `
            @{
                virtualMachineName = $vm.servername ; `
                virtualMachineSize = $vm.VMSize ; `
                adminUsername = "iglooadmin" ; `
                networkInterfaceName = $vm.servername + '-nic'; `
                adminPassword = "P@ssw0rd!234" ; `
                diagnosticsStorageAccountName = $vm.StorageAccount ; `
                subnetName = $vm.subnet ; `
                availabilitySetName = $vm.AvailabilitySet ; `
            }
        }
    }
}