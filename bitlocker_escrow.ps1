<#
.SYNOPSIS
Queries Microsoft Graph for every Windows device in Entra ID and its BitLocker
recovery keys, then writes the combined data to a CSV file.  
Requires delegated scopes Device.Read.All and BitLockerKey.Read.All.
#>

# ── Change-me settings ───────────────────────────────────────────────
$OutputCsv = 'C:\BitlockerKeys.csv'   # <--- set your preferred path here

# ── Helper: fetch full Graph collections ────────────────────────────
function Get-GraphCollection {
    <#
    .SYNOPSIS
        Issues a GET request to a Graph endpoint and follows @odata.nextLink.
    #>
    param(
        [Parameter(Mandatory)][string] $ApiEndpoint,
        [switch]                       $UseGraphModule,
        [hashtable]                    $AuthHeader
    )

    if ($UseGraphModule) {
        $response = Invoke-MgGraphRequest -Uri $ApiEndpoint -Method GET
        $response.Value
        while ($response.'@odata.nextLink') {
            $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET
            $response.Value
        }
    }
    else {
        if (-not $AuthHeader) {
            Write-Error "Please provide an authorization header with -AuthHeader"
            return
        }
        $response = Invoke-RestMethod -Uri $ApiEndpoint -Method GET -Headers $AuthHeader
        $response.Value
        while ($response.'@odata.nextLink') {
            $response = Invoke-RestMethod -Uri $response.'@odata.nextLink' -Method GET -Headers $AuthHeader
            $response.Value
        }
    }
}

# ── Modules ─────────────────────────────────────────────────────────
if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) {
    Write-Host "Installing Microsoft.Graph.Authentication module…"
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph.Authentication

# ── Sign-in ─────────────────────────────────────────────────────────
$scopes = @('Device.Read.All', 'BitLockerKey.Read.All')
Connect-MgGraph -Scopes $scopes | Out-Null

# Verify scopes
foreach ($s in $scopes) {
    if ($s -notin (Get-MgContext).Scopes) {
        Write-Error "Required scope '$s' not present in the access token!"
        return
    }
}

# ── Query devices and keys ──────────────────────────────────────────
$allKeys = Get-GraphCollection `
    -ApiEndpoint "https://graph.microsoft.com/beta/informationProtection/bitlocker/recoveryKeys?`$top=999" `
    -UseGraphModule

$windowsDevices = Get-GraphCollection `
    -ApiEndpoint "https://graph.microsoft.com/v1.0/devices?`$top=100&`$filter=(trustType eq 'azuread') or (trustType eq 'serverad')" `
    -UseGraphModule

# ── Build output objects ────────────────────────────────────────────
$deviceList = foreach ($device in $windowsDevices) {
    $recoveryKeys = $allKeys |
        Where-Object { $_.deviceId -eq $device.deviceId } |
        ForEach-Object {
            $keyDetail = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/informationProtection/bitlocker/recoveryKeys/$($_.id)?`$select=key"
            [pscustomobject]@{
                Key           = $keyDetail.key
                RecoveryKeyID = $keyDetail.id
            }
        }

    [pscustomobject]@{
        DeviceName    = $device.displayName
        DeviceID      = $device.deviceId
        Model         = $device.model
        Manufacturer  = $device.manufacturer
        RecoveryKeys  = ($recoveryKeys | ConvertTo-Json -Compress)
    }
}

# ── Export to CSV ───────────────────────────────────────────────────
$deviceList | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Keys exported to $OutputCsv" -