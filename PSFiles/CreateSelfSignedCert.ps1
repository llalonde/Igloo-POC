# Define certificate start and end dates

$currentDate =Get-Date
$endDate = $currentDate.AddYears(1)
$notAfter = $endDate.AddYears(1)

# Generate new self-signed certificate from “Run as Administrator” PowerShell session

$certName = "Igloo@automation"

$certStore = “Cert:\LocalMachine\My”

$certThumbprint = (New-SelfSignedCertificate `
-DnsName “$certName” `
-CertStoreLocation $CertStore `
-KeyExportPolicy Exportable `
-Provider “Microsoft Enhanced RSA and AES Cryptographic Provider” `
-NotAfter $notAfter).Thumbprint

# Export password-protected pfx file

$pfxPassword = Read-Host -Prompt “Enter password to protect exported certificate:” -AsSecureString
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$pfxFilepath = $dir+"\AutoCert.pfx”

Export-PfxCertificate `
-Cert “$($certStore)\$($certThumbprint)” `
-FilePath $pfxFilepath `
-Password $pfxPassword

# Create Key Credential Object

$cert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate -ArgumentList @($pfxFilepath, $pfxPassword)
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())
$keyId = [guid]::NewGuid()

Import-Module -Name AzureRM.Resources

$keyCredential = New-Object -TypeName Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADKeyCredential

# Define properties of Key Credential object

$keyCredential.StartDate = $currentDate
$keyCredential.EndDate = $endDate
$keyCredential.KeyId = $keyId
#$keyCredential.Type = “AsymmetricX509Cert”
#$keyCredential.Usage = “Verify”
$keyCredential.CertValue = $keyValue

# Define Azure AD Application Properties

$adAppName = "IglooAutomationApps"
$adAppHomePage = "http://Igloo-soft”
$adAppIdentifierUri = "http://igloo-soft”

# Login to Azure Account

Login-AzureRmAccount

# Create new Azure AD Application

$adApp = New-AzureRmADApplication `
-DisplayName $adAppName `
-HomePage $adAppHomePage `
-IdentifierUris $adAppIdentifierUri `
-KeyCredentials $keyCredential

Write-Output “New Azure AD App Id: $($adApp.ApplicationId)”

# Create Azure AD Service Principal

New-AzureRmADServicePrincipal -ApplicationId $adApp.ApplicationId

# Select Azure subscription

$subscriptionId = (Get-AzureRmSubscription | Out-GridView -Title “Select an Azure Subscription …” -PassThru).SubscriptionId

Select-AzureRmSubscription -SubscriptionId $subscriptionId

# Assign Owner permissions to the Service Principal for the selected subscription

New-AzureRmRoleAssignment -RoleDefinitionName Owner -ServicePrincipalName $adApp.ApplicationId

# Set Azure AD Tenant ID

$tenantId = (Get-AzureRmContext).Tenant.TenantId

# Test authenticating as Service Principal to Azure

Login-AzureRmAccount -ServicePrincipal -TenantId $tenantId -ApplicationId $adApp.ApplicationId -CertificateThumbprint $certThumbprint

# Select existing Azure Automation account
$automationAccount = Get-AzureRmAutomationAccount | Out-GridView -Title “Select an existing Azure Automation account …” -PassThru

# Create Azure Automation Asset for Azure AD App ID
New-AzureRmAutomationVariable -Name “AutomationAppId” -Value $adApp.ApplicationId -AutomationAccountName $automationAccount.AutomationAccountName -ResourceGroupName $automationAccount.ResourceGroupName -Encrypted:$false

# Create Azure Automation Asset for Azure AD Tenant ID

New-AzureRmAutomationVariable -Name “AutomationTenantId” -Value $tenantId -AutomationAccountName $automationAccount.AutomationAccountName -ResourceGroupName $automationAccount.ResourceGroupName -Encrypted:$false

# Create Azure Automation Asset for Certificate

New-AzureRmAutomationCertificate -Name “AutomationCertificate” -Path $pfxFilepath -Password $pfxPassword -AutomationAccountName $automationAccount.AutomationAccountName -ResourceGroupName $automationAccount.ResourceGroupName

# Create Azure Automation Asset for Azure Subscription ID

New-AzureRmAutomationVariable -Name “AutomationSubscriptionId” -Value $subscriptionId -AutomationAccountName $automationAccount.AutomationAccountName -ResourceGroupName $automationAccount.ResourceGroupName -Encrypted:$false

# Get Azure Automation Assets

$adAppId = Get-AutomationVariable -Name “AutomationAppId”
Write-Output “Azure AD Application Id: $($adAppId)”

$tenantId = Get-AutomationVariable -Name “AutomationTenantId”
Write-Output “Azure AD Tenant Id: $($tenantId)”

$subscriptionId = Get-AutomationVariable -Name "AutomationSubscriptionId”
Write-Output “Azure Subscription Id: $($subscriptionId)”

$cert = Get-AutomationCertificate -Name “AutomationCertificate”

$certThumbprint = ($cert.Thumbprint).ToString()

Write-Output “Service Principal Certificate Thumbprint: $($certThumbprint)”

# Install Service Principal Certificate

Write-Output “Install Service Principal certificate…”

if ((Test-Path “Cert:\CurrentUser\My\$($certThumbprint)”) -eq $false)
{
    InlineScript {
        $certStore = new-object System.Security.Cryptography.X509Certificates.X509Store(“My”, “CurrentUser”)
        $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $certStore.Add($Using:cert)
        $certStore.Close()
    }
}

