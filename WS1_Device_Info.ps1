# ==============================================================================================
# SCRIPT NAME: WS1_Device_Info.ps1
# DESCRIPTION:
#   This script retrieves Workspace ONE (WS1) device enrollment status using OAuth authentication.
#   It processes:
#     1. Disabled users from PrimaryGroup_Disabled.csv
#     2. Users from BothGroups.csv (filtered by CO/SO ownership)
#   The script:
#     ✅ Queries WS1 API by User ID
#     ✅ Logs enrollment status and device IDs
#     ✅ Outputs CSV reports for review
# REQUIREMENTS:
#   - OAuth credentials (client ID/secret)
#   - WS1 API access and Organization Group permissions
#   - Input CSV files: PrimaryGroup_Disabled.csv and BothGroups.csv
# ==============================================================================================

# ============================
# WS1 API and OAuth Setup
# ============================
$mainPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = "$mainPath\output"
$tokenDir = "$mainPath\token_cache"
$tokenCacheFile = "$tokenDir\ws1_token_cache.json"
$tokenLifetimeSeconds = 3600  # Token validity period (1 hour)

# WS1 API URLs and credentials - REPLACE with your values
$ws1EnvUrl = "<Your_Environment_URL>/API"
$tokenUrl = "<Your_Token_Endpoint>"
$clientId = "<Your_Client_ID>"
$clientSecret = "<Your_Client_Secret>"

# Output CSV file paths
$outputEnrollmentCsv = "$outputDir\Enrollment_Status.csv"
$outputDetailsCsv = "$outputDir\Device_Details.csv"
$outputProfilesCsv = "$outputDir\Device_Profiles.csv"

# Input CSV files
$primaryDisabledCsv = "$outputDir\PrimaryGroup_Disabled.csv"
$bothGroupsCsv = "$outputDir\BothGroups.csv"

# Ensure directories exist
New-Item -ItemType Directory -Force -Path $outputDir -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Force -Path $tokenDir -ErrorAction SilentlyContinue | Out-Null

# Clean previous output
Remove-Item -Path $outputEnrollmentCsv, $outputDetailsCsv, $outputProfilesCsv -Force -ErrorAction SilentlyContinue

# ============================
# Function: Get OAuth Token
# ============================
function Get-WS1Token {
    if (Test-Path $tokenCacheFile) {
        $tokenData = Get-Content $tokenCacheFile | ConvertFrom-Json
        $createdTime = Get-Item $tokenCacheFile | Select-Object -ExpandProperty CreationTimeUtc
        $elapsed = (Get-Date).ToUniversalTime() - $createdTime
        if ($elapsed.TotalSeconds -lt $tokenLifetimeSeconds) {
            return $tokenData.access_token
        }
    }
    $response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Headers @{ "Content-Type" = "application/x-www-form-urlencoded" } `
        -Body @{ grant_type = "client_credentials"; client_id = $clientId; client_secret = $clientSecret }
    $response | ConvertTo-Json | Out-File -FilePath $tokenCacheFile
    return $response.access_token
}

# ============================
# Function: Query Enrollment Status
# ============================
function Get-EnrollmentStatus($userId) {
    $headers = @{ Authorization = "Bearer $(Get-WS1Token)" }
    $url = "$ws1EnvUrl/mdm/devices/search?user=$userId"
    try {
        $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -ErrorAction Stop
        return $result.Devices
    } catch {
        Write-Warning "❌ API call failed for user: $userId"
        return $null
    }
}

# ============================
# Main Execution
# ============================

$logFile = "$outputDir\device_info_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Log($msg) { $msg | Tee-Object -FilePath $logFile -Append }

Log "`n===== WS1 Device Info Script Started: $(Get-Date) =====`n"

$users = @()
if (Test-Path $primaryDisabledCsv) {
    $users += (Import-Csv $primaryDisabledCsv).sAMAccountName
}
if (Test-Path $bothGroupsCsv) {
    $users += (Import-Csv $bothGroupsCsv | Where-Object { $_.'Ownership' -eq 'Corporate-Owned' -or $_.'Ownership' -eq 'Shared' }).'User ID'
}
$users = $users | Sort-Object -Unique

$deviceData = @()
foreach ($user in $users) {
    $devices = Get-EnrollmentStatus -userId $user
    if ($devices) {
        foreach ($device in $devices) {
            $deviceData += [PSCustomObject]@{
                "User ID" = $user
                "Device ID" = $device.Id.Value
                "Enrollment Status" = $device.Status
                "Ownership" = $device.Ownership
                "Platform" = $device.Platform
                "Model" = $device.Model
            }
        }
    }
}

$deviceData | Export-Csv -Path $outputEnrollmentCsv -NoTypeInformation

Log "`n📊 Enrollment Status CSV Generated: $outputEnrollmentCsv`n"
Log "===== Script Complete: $(Get-Date) =====`n"
