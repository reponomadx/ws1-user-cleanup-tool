 <#
.SYNOPSIS
    Workspace ONE User Cleanup Script

.DESCRIPTION
    This PowerShell script audits two Active Directory groups associated with Workspace ONE enrollment,
    identifies disabled users, and compares membership overlap. It generates summary reports
    and optionally invokes a secondary script to evaluate device enrollment status.

.REQUIREMENTS
    - PowerShell
    - RSAT: ActiveDirectory module
    - Workspace ONE Device Details secondary script (optional)

.NOTES
    Ensure group names and base paths are updated to reflect your environment before use.
    All exported data is saved to the script directory for review.

.AUTHOR
    Brian Irish
#>

# Requires RSAT: ActiveDirectory module
Import-Module ActiveDirectory

# Group names (Update with real group names or keep masked)
$group1 = "GROUP_1_PLACEHOLDER"
$group2 = "GROUP_2_PLACEHOLDER"

# Define base path (Update for your environment)
$basePath = "C:\Path\To\WS1UserCleanup"
$secondaryScript = "$basePath\WS1 Device Details.ps1"

# Output paths
$outputDir = "$basePath"
$bothGroupsCsv = "$outputDir\Both_WS1User_Groups.csv"
$disabledCsv   = "$outputDir\Disabled_Accounts_WS1Users.csv"

# Get group DNs
$group1DN = (Get-ADGroup $group1).DistinguishedName
$group2DN = (Get-ADGroup $group2).DistinguishedName

Write-Host "🔍 Getting users from '$group1' and '$group2'..."

# Pull users from each group
$group1Members = Get-ADUser -Filter "MemberOf -eq '$group1DN'" -Properties Enabled, sAMAccountName, givenName, sn
$group2Members = Get-ADUser -Filter "MemberOf -eq '$group2DN'" -Properties Enabled, sAMAccountName, givenName, sn

# Stats
$group1Count = $group1Members.Count
$group2Count = $group2Members.Count
$group1Disabled = ($group1Members | Where-Object { -not $_.Enabled }).Count
$group2Disabled = ($group2Members | Where-Object { -not $_.Enabled }).Count

# Get duplicates
$duplicateUsers = $group1Members | Where-Object {
    $group2Members.DistinguishedName -contains $_.DistinguishedName
}
$duplicateCount = $duplicateUsers.Count
$duplicateDisabled = ($duplicateUsers | Where-Object { -not $_.Enabled }).Count

# Create report for users in both groups
$duplicateResults = $duplicateUsers | Select-Object `
    @{Name="User ID";Expression={$_.sAMAccountName}},
    @{Name="First Name";Expression={$_.givenName}},
    @{Name="Last Name";Expression={$_.sn}},
    @{Name="Status";Expression={if ($_.Enabled) { "Enabled" } else { "Disabled" }}},
    @{Name="In $group1";Expression={"Yes"}},
    @{Name="In $group2";Expression={"Yes"}}

# Export to CSV
$duplicateResults | Export-Csv -Path $bothGroupsCsv -NoTypeInformation

# Create and export disabled accounts from both groups
$disabledUsers = ($group1Members + $group2Members) | Where-Object { -not $_.Enabled } | 
    Sort-Object DistinguishedName -Unique | 
    Select-Object `
        @{Name="User ID";Expression={$_.sAMAccountName}},
        @{Name="First Name";Expression={$_.givenName}},
        @{Name="Last Name";Expression={$_.sn}},
        @{Name="Group Membership";Expression={
            $groups = @()
            if ($group1Members.DistinguishedName -contains $_.DistinguishedName) { $groups += $group1 }
            if ($group2Members.DistinguishedName -contains $_.DistinguishedName) { $groups += $group2 }
            $groups -join ", "
        }}

$disabledUsers | Export-Csv -Path $disabledCsv -NoTypeInformation

# Display summary
Write-Host "`n📊 Summary Totals"
Write-Host "----------------------------"
Write-Host "👤 Total in $group1     : $group1Count"
Write-Host "🚫 Disabled in $group1  : $group1Disabled"
Write-Host "👤 Total in $group2     : $group2Count"
Write-Host "🚫 Disabled in $group2  : $group2Disabled"
Write-Host "👥 In both groups       : $duplicateCount"
Write-Host "🚫 Disabled in both     : $duplicateDisabled"
Write-Host "`n📁 CSV Exported:"
Write-Host " - $bothGroupsCsv"
Write-Host " - $disabledCsv"

# ▶️ Run secondary script to fetch Workspace ONE device details
if (Test-Path $secondaryScript) {
    Write-Host "`n🚀 Running secondary script: WS1 Device Details.ps1"
    & $secondaryScript
} else {
    Write-Host "❌ Could not find secondary script: $secondaryScript"
    exit 1
}

# 📂 Parse output from secondary script
$deviceCsv = "$basePath\ws1_enrollment.csv"
if (-Not (Test-Path $deviceCsv)) {
    Write-Host "❌ Device enrollment results not found at $deviceCsv"
    exit 1
}

$deviceResults = Import-Csv -Path $deviceCsv

# 📊 Present summary by enrollment status
$grouped = $deviceResults | Group-Object "Enrollment Status"
Write-Host "`n📋 Enrollment Status Breakdown:"
foreach ($group in $grouped) {
    Write-Host " - $($group.Name): $($group.Count)"
}
 
