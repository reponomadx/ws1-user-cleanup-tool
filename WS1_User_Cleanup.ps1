# ============================================================================================
# SCRIPT NAME: WS1_User_Cleanup.ps1
# DESCRIPTION:
#   This script queries Active Directory for two Workspace ONE (WS1) groups:
#     - <Primary Workspace ONE Group>
#     - <Secondary Workspace ONE Group>
#   It outputs:
#     ✅ Total users per group
#     ✅ Disabled users per group
#     ✅ Users found in both groups
#   CSV files and a timestamped log are generated.
#   A secondary script (WS1_Device_Info.ps1) is optionally triggered to query device info.
#
# REQUIREMENTS:
#   - RSAT ActiveDirectory module
#   - Required permissions to read AD groups
#   - Optional: Workspace ONE API access handled in WS1_Device_Info.ps1
# ============================================================================================

Import-Module ActiveDirectory

# Group names to query in AD
$primaryGroup = "<Primary_WS1_Group>"
$secondaryGroup = "<Secondary_WS1_Group>"

# Base directory path setup
$mainPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = "$mainPath\output"
$secondaryScript = "$mainPath\WS1_Device_Info.ps1"

# CSV output file paths
$bothGroupsCsv = "$outputDir\BothGroups.csv"
$primaryGroupDisabledCsv = "$outputDir\PrimaryGroup_Disabled.csv"
$secondaryGroupDisabledCsv = "$outputDir\SecondaryGroup_Disabled.csv"

# Timestamped log file path
$timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")

if (!(Test-Path "$outputDir\logs")) {
    New-Item -ItemType Directory -Path "$outputDir\logs" | Out-Null
}
$logFile = "$outputDir\logs\user_cleanup_summary_$timestamp.log"

function Log {
    param ($Message)
    $Message | Tee-Object -FilePath $logFile -Append
}

Log "`n===== Workspace ONE User Cleanup Script Started: $(Get-Date) =====`n"
Log "🔍 Querying users from '$primaryGroup' and '$secondaryGroup'..."

# Query all users in each group from AD
$primaryGroupMembers = Get-ADUser -Filter "MemberOf -eq '$((Get-ADGroup $primaryGroup).DistinguishedName)'" `
    -Properties Enabled, sAMAccountName, givenName, sn, DistinguishedName

$secondaryGroupMembers = Get-ADUser -Filter "MemberOf -eq '$((Get-ADGroup $secondaryGroup).DistinguishedName)'" `
    -Properties Enabled, sAMAccountName, givenName, sn, DistinguishedName

# Find users who exist in both groups
$duplicateUsers = $primaryGroupMembers | Where-Object {
    $secondaryGroupMembers.DistinguishedName -contains $_.DistinguishedName
}

# Export disabled users
$primaryGroupMembers | Where-Object { -not $_.Enabled } |
    Select-Object sAMAccountName, givenName, sn |
    Export-Csv -Path $primaryGroupDisabledCsv -NoTypeInformation

$secondaryGroupMembers | Where-Object { -not $_.Enabled } |
    Select-Object sAMAccountName, givenName, sn |
    Export-Csv -Path $secondaryGroupDisabledCsv -NoTypeInformation

# Export users in both groups
$duplicateUsers | Select-Object `
    @{Name="User ID";Expression={$_.sAMAccountName}},
    @{Name="First Name";Expression={$_.givenName}},
    @{Name="Last Name";Expression={$_.sn}},
    @{Name="Status";Expression={if ($_.Enabled) { "Enabled" } else { "Disabled" }}},
    @{Name="In Primary Group";Expression={"Yes"}},
    @{Name="In Secondary Group";Expression={"Yes"}} |
    Export-Csv -Path $bothGroupsCsv -NoTypeInformation

# Summary counts
$primaryCount = @($primaryGroupMembers).Count
$secondaryCount = @($secondaryGroupMembers).Count
$primaryDisabled = @(Import-Csv $primaryGroupDisabledCsv).Count
$secondaryDisabled = @(Import-Csv $secondaryGroupDisabledCsv).Count
$bothCount = @($duplicateUsers).Count

Log "`n📊 Summary Totals"
Log "----------------------------"
Log "👤 Total in $primaryGroup : $primaryCount"
Log "🚫 Disabled in $primaryGroup : $primaryDisabled"
Log "👤 Total in $secondaryGroup : $secondaryCount"
Log "🚫 Disabled in $secondaryGroup : $secondaryDisabled"
Log "👥 Users in both groups : $bothCount"

function LogCsvData {
    param ($FilePath, $Title)
    if (Test-Path $FilePath) {
        $csvData = Get-Content $FilePath
        Log "`n📁 $Title ($FilePath):"
        foreach ($line in $csvData) { Log "  $line" }
    } else {
        Log "`n❌ CSV file not found: $FilePath"
    }
}

# Log snapshots
LogCsvData -FilePath $bothGroupsCsv -Title "BothGroups.csv"
LogCsvData -FilePath $primaryGroupDisabledCsv -Title "PrimaryGroup_Disabled.csv"
LogCsvData -FilePath $secondaryGroupDisabledCsv -Title "SecondaryGroup_Disabled.csv"

if (Test-Path $secondaryScript) {
    Log "`n🚀 Running secondary script: WS1_Device_Info.ps1"
    & $secondaryScript | Tee-Object -FilePath $logFile -Append
} else {
    Log "❌ Secondary script not found: $secondaryScript"
}

$deviceCsv = "$outputDir\Device_Details.csv"
if (Test-Path $deviceCsv) {
    $deviceData = Import-Csv $deviceCsv
    $statusCounts = $deviceData | Group-Object "Enrollment Status"

    Log "`n📋 Enrollment Status Breakdown:"
    foreach ($status in $statusCounts) {
        Log " - $($status.Name): $($status.Count)"
    }
    LogCsvData -FilePath $deviceCsv -Title "Device_Details.csv"
} else {
    Log "❌ Device CSV not found: $deviceCsv"
}

Log "`n===== Script Complete: $(Get-Date) =====`n"
