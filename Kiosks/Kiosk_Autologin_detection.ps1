# Prevent remediation from running during Autopilot ESP. Changing the autologin during ESP, will break Autopilot processes
$processesExplorer = @(Get-CimInstance -ClassName 'Win32_Process' -Filter "Name like 'explorer.exe'" -ErrorAction 'Ignore')
$esp = $false
foreach ($processExplorer in $processesExplorer) {
    $user = (Invoke-CimMethod -InputObject $processExplorer -MethodName GetOwner).User
    if ($user -eq 'defaultuser0' -or $user -eq 'defaultuser1') { Write-host "Device is still running ESP"; Exit 0 }
}

# Set Registry Values to autologin
if ((Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoAdminLogon' -ea SilentlyContinue) -eq '1') {  } else { Write-Host "AutoAdminLogon Values Do Not Exist. Running Remediation.... return"; Exit 1 };
if ((Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'DefaultDomainName' -ea SilentlyContinue) -eq '.') {  } else { Write-Host "DefaultDomainName Values Do Not Exist. Running Remediation...."; Exit 1 };
if ((Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'DefaultUserName' -ea SilentlyContinue) -eq 'kioskUser0') {  } else { Write-Host "DefaultUserName Values Do Not Exist. Running Remediation...."; Exit 1 };

Write-Output "Registry keys are set correctly."