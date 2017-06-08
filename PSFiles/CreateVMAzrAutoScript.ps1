workflow CreateVMFromList
{
    $servicePrincipalConnection = Get-AutomationConnection -Name AzureRunAsConnection         
		
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
    $destination = "c:\csv_files/VMList.csv"
    "Dowloading CSV file to Azure Automation Instance..."
    Invoke-WebRequest $source -OutFile $destination

    $VMList= import-csv $destination
    "Start processing loop..."
    ForEach ( $VM in $VMList) {
            $VMName = $VM.ServerName
            $ASname = $VM.AvailabilitySet
            $VMsubnet = $VM.subnet
            $VMOS = $VM.OS
            $VMStorage = $vm.StorageAccount
            $VMSize = $vm.VMSize
            $VMDataDiskSize = $vm.DataDiskSize
            "Write output..."
            $VMName
            $ASname
            $VMsubnet
            $VMOS
            $VMStorage
            $VMSize
            $VMDataDiskSize
    }
}