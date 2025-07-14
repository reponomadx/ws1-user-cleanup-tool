# ==============================================================================================
# SCRIPT NAME: WS1_Device_Profiles.ps1
# DESCRIPTION:
#   This script queries Workspace ONE (WS1) for assigned profiles on devices.
#   ✅ Uses OAuth for API authentication
#   ✅ Reads device IDs from Device_Details.csv
#   ✅ Filters profiles containing 'Restrictions' in the name
#   ✅ Exports results to Device_Profiles.csv
#
# REQUIREMENTS:
#   - OAuth credentials (Client ID/Secret)
#   - WS1 API access permissions
#   - Input CSV (Device_Details.csv) with Device ID
# ==============================================================================================

# ============================
# Workspace ONE API Setup
# ============================
$mainPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = "$mainPath\output"
$tokenDir = "$mainPath\token_cache"
$tokenCacheFile = "$tokenDir\ws1_token_cache.json"
$tokenLifetimeSeconds = 3600

# WS1 API credentials and URLs - REPLACE with your own values
$ws1EnvUrl = "<Your_Environment_URL>/API"
$tokenUrl = "<Your_Token_Endpoint>"
$clientId = "<Your_Client_ID>"
$clientSecret = "<Your_Client_Secret>"

# Output and input files
$outputProfilesCsv = "$outputDir\Device_Profiles.csv"
$inputDeviceCsv = "$outputDir\Device_Details.csv"

# Ensure necessary directories exist
New-Item -ItemType Directory -Force -Path $outputDir -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Force -Path $tokenDir -ErrorAction SilentlyContinue | Out-Null

# Clean previous output file
Remove-Item -Path $outputProfilesCsv -Force -ErrorAction SilentlyContinue

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
# Main Execution
# ============================

$logFile = "$outputDir\device_profiles_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Log($msg) { $msg | Tee-Object -FilePath $logFile -Append }

Log "`n===== WS1 Device Profiles Script Started: $(Get-Date) =====`n"

if (-not (Test-Path $inputDeviceCsv)) {
    Log "❌ Input file not found: $inputDeviceCsv"
    exit 1
}

$deviceList = Import-Csv $inputDeviceCsv

$profileResults = @()
foreach ($device in $deviceList) {
    $deviceId = $device.'Device ID'
    $headers = @{ Authorization = "Bearer $(Get-WS1Token)" }
    $profileUrl = "$ws1EnvUrl/mdm/devices/$deviceId/profiles"

    try {
        $profiles = Invoke-RestMethod -Method Get -Uri $profileUrl -Headers $headers -ErrorAction Stop
        foreach ($profile in $profiles.DeviceProfiles) {
            if ($profile.ProfileName -like "*Restrictions*") {
                $profileResults += [PSCustomObject]@{
                    "Device ID" = $deviceId
                    "Profile Name" = $profile.ProfileName
                    "Profile ID" = $profile.ProfileId
                }
            }
        }
    } catch {
        Log "❌ Failed to retrieve profiles for device: $deviceId"
    }
}

$profileResults | Export-Csv -Path $outputProfilesCsv -NoTypeInformation

Log "`n📊 Device Profiles CSV Generated: $outputProfilesCsv`n"
Log "===== Script Complete: $(Get-Date) =====`n"
