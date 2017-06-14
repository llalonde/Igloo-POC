$results = Enable-PSRemoting -Force

$folder = "c:\temp"
$log = "c:\temp\azurelog.txt"
$date = Get-Date


New-Item -Path $folder -ItemType Directory
New-Item -Path $log -ItemType File
Add-Content -Value " WinRM and Remote Powershell setup - $date $results" -Path $log