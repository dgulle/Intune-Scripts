<#
.SYNOPSIS
This script retrieves devices managed in Microsoft Intune that belong to a specified Entra ID group. 
It can display the results in the PowerShell console, export them to a CSV file, or perform both actions 
based on the provided parameters.

.DESCRIPTION
The script connects to Microsoft Graph using the Microsoft.Graph.Authentication module, 
fetches members of a specified Entra ID group, and retrieves all managed devices in Intune. 
It then matches devices belonging to the group and outputs the results based on the provided parameters.

.PARAMETER group
Specifies the name of the Entra ID group. This parameter is mandatory.

.PARAMETER list
If specified, the script will display the matching devices in the PowerShell console.

.PARAMETER outputfile
Specifies the path to export the matching devices to a CSV file. 
If not specified, the default path is "C:\devices.csv".

.EXAMPLE
.\Device_upn.ps1 -group "GroupName" -list
Displays the matching devices in the PowerShell console for the specified group.

.EXAMPLE
.\Device_upn.ps1 -group "GroupName" -outputfile "D:\output.csv"
Exports the matching devices to "D:\output.csv" for the specified group.

.EXAMPLE
.\Device_upn.ps1 -group "GroupName" -list -outputfile "D:\output.csv"
Displays the matching devices in the console and exports them to "D:\output.csv" for the specified group.

.NOTES
Ensure that the Microsoft.Graph.Authentication module is installed and that you have the necessary permissions 
to access group and device information in Microsoft Graph.

The script will only perform the actions explicitly specified by the user. For example:
- If `-list` is provided, it will only display the results in the console.
- If `-outputfile` is provided, it will only export the results to a CSV file.
- If both `-list` and `-outputfile` are provided, it will perform both actions.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$group,

    [switch]$list,

    [string]$outputfile = "C:\devices.csv"
)


# Ensure Microsoft Graph module is installed and imported
if (!(Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module Microsoft.Graph.Authentication -Force
}
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

# Authenticate with Microsoft Graph
    
if (-not (Get-MgContext)) {
    Write-Host "Authenticating with MS Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes @(
        "GroupMember.Read.All", 
        "Directory.Read.All", 
        "Group.Read.All", 
        "Group.ReadWrite.All", 
        "GroupMember.ReadWrite.All", 
        "DeviceManagementManagedDevices.Read.All",
        "DeviceManagementConfiguration.Read.All"
    )
}


# Retrieve Group ID from Group Name
Write-Host "Retrieving Group ID for group: $group..." -ForegroundColor Yellow
$groupResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$group'"

if ($groupResponse.value.Count -eq 0) {
    Write-Error "Group '$group' not found."
    exit
}
$groupId = $groupResponse.value[0].id
Write-Host "Group ID retrieved:" -ForegroundColor Green -NoNewline; Write-Host " $groupId" -ForegroundColor Yellow

# Fetch group members
$groupMembersResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members"
$groupmembers = $groupMembersResponse.value

# Fetch all managed devices
$devices = @()
$deviceResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
$devices += $deviceResponse.value

while ($deviceResponse.'@odata.nextLink') {
    $deviceResponse = Invoke-MgGraphRequest -Method GET -Uri $deviceResponse.'@odata.nextLink'
    $devices += $deviceResponse.value
}


# Collect matching devices
$matchingDevices = @()
foreach ($member in $groupmembers) {
    if ($member.deviceid) {
        # Ensure the member has a device ID
        foreach ($device in $devices) {
            if ($member.deviceid -eq $device.azureADDeviceId) {
                $matchingDevices += [pscustomobject]@{
                    'Device Name'      = $device.deviceName
                    'Serial Number'    = $device.serialNumber
                    'Compliance State' = $device.complianceState
                    'UPN'              = $device.userPrincipalName
                    'Username'         = $device.userDisplayName
                    'E mail'           = $device.emailAddress
                }
            }
        }
    }
}



# Output results
if ($matchingDevices.Count -gt 0) {
    if ($list -and -not $PSBoundParameters.ContainsKey('outputfile')) {
        # Only list the results
        Write-Host "Matching Devices:" -ForegroundColor Cyan
        $matchingDevices | Format-Table -AutoSize
        Exit 0
    }
    elseif ($PSBoundParameters.ContainsKey('outputfile') -and -not $list) {
        # Only export to CSV
        $matchingDevices | Export-Csv -Path $outputfile -NoTypeInformation
        Write-Host "Device information exported to" -ForegroundColor Green -NoNewline; Write-Host " $outputfile" -ForegroundColor Yellow
        Exit 0
    }
    elseif ($list -and $PSBoundParameters.ContainsKey('outputfile')) {
        # Do both actions
        Write-Host "Matching Devices:" -ForegroundColor Cyan
        $matchingDevices | Format-Table -AutoSize
        $matchingDevices | Export-Csv -Path $outputfile -NoTypeInformation
        Write-Host "Device information exported to" -ForegroundColor Green -NoNewline; Write-Host " $outputfile" -ForegroundColor Yellow
        Exit 0
    }
}
else {
    Write-Host "No matching devices found." -ForegroundColor Red
}