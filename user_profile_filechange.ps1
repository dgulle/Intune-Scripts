<# 
    Purpose:  This script updates the `file.config` file located in the `AppData\Roaming` directory for all real user profiles on a Windows machine. 
    It is designed to be run as SYSTEM, and will iterate through each user profile to apply necessary changes to their respective configuration files.
    This can be used to install Win32 apps as SYSTEM, but still modify the user profile settings.

    Synopsis:
    - Discovers all user profiles on the system, excluding default, public, and other non-real profiles.
    - Generates the full path to the `file.config` file for each user profile.
    - Reads the content of each `file.config` file and applies modifications based on predefined rules.
    - Logs all operations, including discovered profiles, processed files, and any errors encountered.
    - Skips profiles or files that are missing or inaccessible.

    Usage:
    - Deploy via Intune as SYSTEM to ensure access to all user profiles.
    - Ensure the script is executed in a 64-bit PowerShell environment for compatibility.
    #>

# Configurable variables
# Define the path to the configuration file relative to each user profile
$ConfigFile = 'AppData\Roaming\file.config'

# Logging setup
$LogFolder = 'C:\ProgramData\IntuneScripts'
$LogPath = Join-Path $LogFolder 'FileConfigUpdate.log'
if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null }

# Start transcript for logging
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
