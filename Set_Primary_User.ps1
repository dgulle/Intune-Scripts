<#
.SYNOPSIS
This script sets the primary user for devices managed in Microsoft Intune using the Microsoft Graph API. It allows filtering devices based on specific criteria and assigns the primary user based on the last logged-in user.

.DESCRIPTION
The script connects to Microsoft Graph and retrieves devices based on the provided filter criteria. It supports filtering by exact device name, partial matches, or retrieving all Windows devices. After retrieving the devices, the script prompts the user for confirmation before proceeding to set the primary user for each device. The primary user is determined based on the last logged-in user.

.PARAMETER Device
Filters devices by an exact device name.
Example:
    .\Set_Primary_User.ps1 -Device "Device123"

.PARAMETER DeviceContains
Filters devices where the name contains a specific substring.
Example:
    .\Set_Primary_User.ps1 -DeviceContains "Device"

.PARAMETER DeviceIn
Filters devices by a comma-separated list of device names.
Example:
    .\Set_Primary_User.ps1 -DeviceIn "Device1,Device2,Device3"

.PARAMETER All
Retrieves all devices running the Windows operating system.
Example:
    .\Set_Primary_User.ps1 -All

.PARAMETER Top
Limits the number of devices retrieved.
Example:
    .\Set_Primary_User.ps1 -DeviceContains "Device" -Top 10

.NOTES
- The script requires the `Microsoft.Graph.Authentication` and `Microsoft.Graph.Beta.DeviceManagement` modules.
- Ensure that the user running the script has appropriate permissions in Microsoft Intune and Microsoft Graph API.
- At least one parameter (`-Device`, `-DeviceContains`, or `-All`) must be specified for the script to run.

.EXAMPLES
# Set the primary user for a specific device
.\Set_Primary_User.ps1 -Device "Device123"

# Set the primary user for devices matching a substring
.\Set_Primary_User.ps1 -DeviceContains "Device"

# Set the primary user for all Windows devices
.\Set_Primary_User.ps1 -All

# Limit the number of devices processed
.\Set_Primary_User.ps1 -DeviceContains "Device" -Top 5
#>

param (
    [string]$Device,
    [string]$DeviceContains,
    [int]$Top,
    [switch]$All
)

# Ensure at least one parameter is provided
if (-not $Device -and -not $DeviceContains -and -not $DeviceIn -and -not $All) {
    Write-Error "You must specify at least one of the following parameters: -Device, -DeviceContains, or -All."
    exit
}

# Check for and install the required modules
$requiredModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Beta.DeviceManagement')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Install-Module -Name $module -Force
    }
    Import-Module -Name $module
}

# Connect to Microsoft Graph
if (-not (Get-MgContext)) {
    Connect-MgGraph
}

# Build the filter query
$filter = if ($All) {
    "operatingSystem eq 'Windows'"
}
elseif ($Device) {
    "deviceName eq '$Device'"
}
elseif ($DeviceContains) {
    "contains(deviceName, '$DeviceContains')"
} 
else {
    $null
}

Write-Host "Filter Query: $filter"

# Validate the filter query
if (-not $filter) {
    Write-Error "The filter query could not be constructed. Ensure that one of the parameters (-Device, -DeviceContains, -DeviceIn, or -All) is specified and valid."
    exit
}

# Get the devices with optional Top parameter
try {
    if ($Top) {
        $devices = Get-MgBetaDeviceManagementManagedDevice -Filter $filter -Top $Top
        Write-Host "Top $Top devices retrieved."
    }
    else {
        $devices = Get-MgBetaDeviceManagementManagedDevice -Filter $filter
        Write-Host "All devices retrieved."
    }

    # Debug output
    Write-Host "Devices Retrieved: $($devices.Count)" -ForegroundColor Yellow
    Write-Host "Devices:" -ForegroundColor Cyan
    $devices | ForEach-Object { Write-Host "DeviceName: $($_.DeviceName), Id: $($_.Id), UserPrincipalName: $($_.UserPrincipalName)" -ForegroundColor Cyan }
}
catch {
    Write-Error "Failed to retrieve devices. Error: $_"
    exit
}

# Handle empty devices
if (-not $devices -or $devices.Count -eq 0) {
    Write-Warning "No devices were retrieved. Check the filter query and ensure the specified parameters match existing devices."
    exit
}

# Prompt user for confirmation before proceeding
Write-Host "This will change the primary user on $($devices.Count) devices. Are you sure you want to proceed? (Y/N)" -ForegroundColor Yellow
$response = Read-Host "Enter Y to proceed or N to cancel"

if ($response -notin @('Y', 'y')) {
    Write-Host "Operation canceled by the user." -ForegroundColor Red
    exit
}

# Process each device
foreach ($d in $devices) {
    Write-Host "Processing device: $($d.DeviceName)" -ForegroundColor Green
    # Get the last logged in user
    $lastLoggedInUser = $d | Select-Object -ExpandProperty UsersLoggedOn
}

# Set the primary user
if ($lastLoggedInUser) {
    # Endpoint URL for setting the primary user
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices(`'$($d.Id)`')/users/`$ref"

    $Body = @{ "@odata.id" = "https://graph.microsoft.com/beta/users/$($lastLoggedInUser.UserId)" } | ConvertTo-Json
    $Method = "POST"

    Invoke-MgGraphRequest -Method $Method -Uri $uri -Body $Body
} else {
    Write-Warning "No logged-in user found for device: $($d.DeviceName)"
}