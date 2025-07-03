<# 
.SYNOPSIS
    Updates the `file.config` file located in the `AppData\Roaming` directory for all real user profiles on a Windows machine.

.DESCRIPTION
    This script is designed to be executed as SYSTEM and iterates through all user profiles on the system, excluding default, public, and other non-real profiles. 
    It identifies the `file.config` file for each profile, applies predefined modifications, and logs all operations, including errors and skipped profiles.

.NOTES
    Version: 1.0
    - Ensure the script is executed in a 64-bit PowerShell environment for compatibility.
    - Deploy via Intune as SYSTEM to ensure access to all user profiles.
#>

# Define the path to the configuration file relative to each user profile
$ConfigFile = 'AppData\Roaming\file.config'

# Logging setup
$LogFolder = 'C:\ProgramData\IntuneScripts'
$LogPath = Join-Path $LogFolder 'FileConfigUpdate.log'
if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null }

Start-Transcript -Path $LogPath -Append -Force

# Grab real profile paths
$excluded = @('Public', 'Default', 'DefaultUser0', 'All Users')
$profiles = Get-ChildItem 'C:\Users' -Directory |
Where-Object { $excluded -notcontains $_.Name } |
Select-Object -ExpandProperty FullName
Write-Host "Discovered profiles: $($profiles -join ', ')"

# Generate $cfg paths for all profiles
$cfgPaths = @{ }
foreach ($userProfile in $profiles) {
    $cfg = Join-Path $userProfile $ConfigFile
    $cfgPaths[$userProfile] = $cfg
}
Write-Host "Generated config paths: $($cfgPaths.Values -join ', ')"

# Define your file-modification logic
function Update-ConfigFile {
    param([string]$ConfigPath)

    try {
        $content = Get-Content -Path $ConfigPath -Raw
        ##################################
        # Modify the new content as needed
        ##################################
        # Example: Change 'Something=false' to 'Something=true'
        $newContent = $content -replace 'Something=false', 'Something=true'

        if ($newContent -ne $content) {
            Write-Host "Updating $ConfigPath"
            $newContent | Set-Content -Path $ConfigPath -Encoding UTF8
        }
        else {
            Write-Host "No change needed in $ConfigPath" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "Error processing $ConfigPath : $_" -ForegroundColor Red
    }
}

# Iterate through each profile's config path
foreach ($userProfile in $cfgPaths.Keys) {
    $cfg = $cfgPaths[$userProfile]
    if (Test-Path $cfg) { Update-ConfigFile -ConfigPath $cfg }
    else { Write-Host "Skipped (missing): $cfg" -ForegroundColor Yellow }
}

Stop-Transcript