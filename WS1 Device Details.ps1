<#
.SYNOPSIS
    Workspace ONE Device Details Script

.DESCRIPTION
    This script supports a WS1 user cleanup workflow by:
    1. Querying device enrollment status for disabled accounts.
    2. Checking device assignments for users in both AD groups.

.REQUIREMENTS
    - PowerShell 5+
    - OAuth credentials for Workspace ONE API access
    - Proper CSV inputs exported from the AD group comparison script

.NOTES
    This version uses only OAuth 2.0.
    Store OAuth credentials securely (do not hardcode secrets in production).

.AUTHOR
    Brian Irish
#>

# Workspace ONE API & OAuth Configuration
$basePath = "C:\Path\To\WS1UserCleanup"  # TODO: Adjust this path
$oauthDir = "$basePath\oauth_token"
$tokenCacheFile = "$oauthDir\ws1_token_cache.json"
$tokenLifetimeSeconds = 3600

$ws1EnvUrl = "https://your-env.awmdm.com/API"  # TODO: Update for your tenant
$tokenUrl = "https://na.uemauth.workspaceone.com/connect/token"

# OAuth credentials (replace with secure storage)
$clientId = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"

$outputFile1 = "$basePath\ws1_enrollment.csv"
$outputFile2 = "$basePath\WS1_Details_BothADGroups.csv"

# Prepare directories and clean existing output
New-Item -ItemType Directory -Force -Path $basePath -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Force -Path $oauthDir -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Path $outputFile1, $outputFile2 -Force -ErrorAction SilentlyContinue

# Token retrieval
function Get-WS1Token {
    if (Test-Path $tokenCacheFile) {
        $tokenData = Get-Content $tokenCacheFile | ConvertFrom-Json
        $tokenAge = (Get-Date) - [datetime]::ParseExact($tokenData.generated_at, "o", $null)
        if ($tokenAge.TotalSeconds -lt $tokenLifetimeSeconds) {
            return $tokenData.access_token
        }
    }

    Write-Host "🔐 Requesting new Workspace ONE access token..."
    $body = "grant_type=client_credentials&client_id=$clientId&client_secret=$clientSecret"
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded'

    if (-not $response.access_token) {
        Write-Host "❌ Failed to obtain access token. Exiting."
        exit 1
    }

    $tokenData = @{ access_token = $response.access_token; generated_at = (Get-Date).ToString("o") }
    $tokenData | ConvertTo-Json -Depth 3 | Set-Content -Path $tokenCacheFile
    return $response.access_token
}

# Get cached token
$accessToken = Get-WS1Token

# ===============================
# 1️⃣ Process Disabled Accounts
# ===============================
Write-Host "`n📋 Retrieving enrollment status (Disabled Accounts)..."
$csvPath1 = "$basePath\Disabled_Accounts_WS1Users.csv"
if (-Not (Test-Path $csvPath1)) {
    Write-Host "❌ Input file not found: $csvPath1"
    exit 1
}

$identifiers1 = Import-Csv -Path $csvPath1 | Select-Object -ExpandProperty "User ID" | Where-Object { $_ -match '^\d{9}$' }
"User ID,Enrollment Status,Device ID" | Out-File -FilePath $outputFile1

$counter1 = 0; $progressCounter = 0
foreach ($id in $identifiers1) {
    $counter1++; $progressCounter++
    if ($progressCounter -ge 35) { Write-Host "*"; $progressCounter = 0 } else { Write-Host -NoNewline "*" }

    $url = "$ws1EnvUrl/mdm/devices/search?user=$id"
    try {
        $response = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $accessToken"; Accept = "application/json" } -Method Get
        $devices = $response.Devices
        if (-not $devices) {
            "${id},No Devices Found," | Out-File -FilePath $outputFile1 -Append
            continue
        }
        foreach ($device in $devices) {
            "$($device.UserName),$($device.EnrollmentStatus),$($device.Id.Value)" | Out-File -FilePath $outputFile1 -Append
        }
    } catch {
        "${id},Error: $($_.Exception.Message)," | Out-File -FilePath $outputFile1 -Append
    }
}
Write-Host "`n✅ Completed: $counter1 records to $outputFile1"

# ===============================
# 2️⃣ Process Both AD Groups (C/S only)
# ===============================
Write-Host "`n📋 Retrieving enrollment status (Both AD Groups)..."
$csvPath2 = "$basePath\Both_WS1User_Groups.csv"
if (-Not (Test-Path $csvPath2)) {
    Write-Host "❌ Input file not found: $csvPath2"
    exit 1
}

$identifiers2 = Import-Csv -Path $csvPath2 | Where-Object { $_."User ID" -match '^\d{9}$' }
"User ID,Enrollment Status,Device ID,Serial Number" | Out-File -FilePath $outputFile2

$counter2 = 0; $progressCounter = 0
foreach ($record in $identifiers2) {
    $counter2++; $progressCounter++
    if ($progressCounter -ge 35) { Write-Host "*"; $progressCounter = 0 } else { Write-Host -NoNewline "*" }

    $userID = $record."User ID"
    $url = "$ws1EnvUrl/mdm/devices/search?user=$userID"
    try {
        $response = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $accessToken"; Accept = "application/json" } -Method Get
        $devices = $response.Devices
        if (-not $devices) {
            "$userID,No Devices Found,," | Out-File -FilePath $outputFile2 -Append
            continue
        }

        foreach ($device in $devices) {
            if ($device.Ownership -eq 'C' -or $device.Ownership -eq 'S') {
                "$userID,$($device.EnrollmentStatus),$($device.Id.Value),$($device.SerialNumber)" | Out-File -FilePath $outputFile2 -Append
            }
        }
    } catch {
        "$userID,Error: $($_.Exception.Message),," | Out-File -FilePath $outputFile2 -Append
    }
}
Write-Host "`n✅ Completed: $counter2 records to $outputFile2"
