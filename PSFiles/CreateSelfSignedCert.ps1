# Define certificate start and end dates

$currentDate = Get-Date
$endDate = $currentDate.AddYears(1)
$notAfter = $endDate.AddYears(1)

# Generate new self-signed certificate from “Run as Administrator” PowerShell session

#$certName = Read-Host -Prompt 'Enter FQDN Subject Name for certificate'
$certName = "pierre@roman.ca"
$certStore = 'Cert:\LocalMachine\My'
$certThumbprint = (New-SelfSignedCertificate -DnsName $certName -CertStoreLocation $CertStore -KeyExportPolicy Exportable -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' -NotAfter $notAfter).Thumbprint

# Export password-protected pfx file
$pfxPassword = Read-Host -Prompt "Enter password to protect exported certificate:" -AsSecureString
$scriptpath = $MyInvocation.MyCommand.Path
$pfxFilepath  = Split-Path $scriptpath
Export-PfxCertificate -Cert "$($certStore)\$($certThumbprint)" -FilePath $pfxFilepath -Password $pfxPassword