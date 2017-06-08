$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$RunAsScript = $dir+"\New-RunAsAccount.ps1"
$ArgumentList = "-ResourceGroup $ResourceGroupName -AutomationAccountName AzrAutoAccount -SubscriptionId $subscriptionId -ApplicationDisplayName AzrAutomationAccount -SelfSignedCertPlainPassword P@ssw0rd!234 -CreateClassicRunAsAccount $false"
#Invoke-Expression "$RunAsScript $argumentList"