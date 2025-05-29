<#
.SYNOPSIS
    Retrieves Entra (Azure AD) Device IDs for a list of device names, exports the results to CSV (optional), and optionally adds the devices to an Entra group.

.DESCRIPTION
    This script accepts a comma-separated list of device names or a CSV file containing device names, queries Entra ID (Azure AD) for their Device IDs, and outputs the results (Device Name and Device ID) to a specified CSV file or to the console. If a Group ID is provided, the script will also add the found devices to the specified Entra group.

.PARAMETER DeviceNames
    Comma-separated list of device names (e.g., "PC1,PC2,PC3").

.PARAMETER DeviceCsvPath
    Path to a CSV file with a column named 'DeviceName' containing device names.

.PARAMETER GroupId
    (Optional) The Entra (Azure AD) Group ID to which the devices should be added.

.PARAMETER OutputCsvPath
    Path to the output CSV file where results will be saved.

.EXAMPLE
    .\Get-EntraDeviceID.ps1 -DeviceNames "PC1,PC2" -OutputCsvPath "output.csv"

.EXAMPLE
    .\Get-EntraDeviceID.ps1 -DeviceCsvPath "devices.csv" -GroupId "<group-guid>" -OutputCsvPath "output.csv"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DeviceNames, # Comma-separated list: "PC1,PC2,PC3"

    [Parameter(Mandatory=$false)]
    [string]$DeviceCsvPath, # Path to CSV with a column 'DeviceName'

    [Parameter(Mandatory=$false)]
    [string]$GroupId, # Entra Group ID

    [Parameter(Mandatory=$true)]
    [string]$OutputCsvPath # Output CSV path (mandatory in this version)
)

if (-not $DeviceNames -and -not $DeviceCsvPath) {
    Write-Error "You must specify either -DeviceNames or -DeviceCsvPath."
    exit 1
}

# Ensure Microsoft Graph modules are installed
$modules = @("Microsoft.Graph.Identity.DirectoryManagement", "Microsoft.Graph.Authentication", "Microsoft.Graph.Groups")
foreach ($mod in $modules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Install-Module $mod -Scope CurrentUser -Force
    }
    Import-Module $mod
}

# Connect to Graph
Connect-MgGraph -Scopes "Device.Read.All","GroupMember.ReadWrite.All"

# Gather device names
$allDeviceNames = @()
if ($DeviceNames) {
    $allDeviceNames += $DeviceNames -split ','
}
if ($DeviceCsvPath) {
    $csvDevices = Import-Csv -Path $DeviceCsvPath
    $allDeviceNames += $csvDevices | ForEach-Object { $_.DeviceName }
}
$allDeviceNames = $allDeviceNames | Where-Object { $_ -and $_.Trim() } | Select-Object -Unique

# Query Entra for device IDs
$results = @()
foreach ($name in $allDeviceNames) {
    $device = Get-MgDevice -Filter "displayName eq '$name'" -ErrorAction SilentlyContinue
    if ($device) {
        $results += [PSCustomObject]@{
            DeviceName = $name
            DeviceId   = $device.Id
        }
        # Add to group if GroupId specified
        if ($GroupId) {
            try {
                New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $device.Id -ErrorAction Stop
                Write-Host "Added $name to group $GroupId"
            } catch {
                Write-Warning "Failed to add $name to group: $_"
            }
        }
    } else {
        $results += [PSCustomObject]@{
            DeviceName = $name
            DeviceId   = "Not found"
        }
        Write-Warning "Device $name not found in Entra."
    }
}

# Export results
$results | Export-Csv -Path $OutputCsvPath -NoTypeInformation

Write-Host "Export complete: $OutputCsvPath"