# ==============================================================================================
# SCRIPT NAME: Remove_From_AD_Group.ps1
# DESCRIPTION:
#   This script reads disabled user lists from CSV files and removes users from two
#   Active Directory (AD) groups:
#     ✅ <Primary AD Group>
#     ✅ <Secondary AD Group>
#   Uses sAMAccountName from the CSV files to identify and remove users from their respective groups.
#
# REQUIREMENTS:
#   - RSAT ActiveDirectory module installed
#   - PrimaryGroup_Disabled.csv and SecondaryGroup_Disabled.csv files present in /output
# ==============================================================================================

# ============================
# Import Active Directory Module
# ============================
Import-Module ActiveDirectory

# ============================
# Define File Paths
# ============================
$mainPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = "$mainPath\output"

$primaryCsv = "$outputDir\PrimaryGroup_Disabled.csv"
$secondaryCsv = "$outputDir\SecondaryGroup_Disabled.csv"

# ============================
# Define AD Group Names
# ============================
$primaryGroup = "<Primary_AD_Group>"
$secondaryGroup = "<Secondary_AD_Group>"

# ============================
# Import CSV Data
# ============================
$listPrimary = Import-Csv -Path $primaryCsv
$listSecondary = Import-Csv -Path $secondaryCsv

Write-Host "`n📋 Processing Disabled Users for Removal from AD Groups..." -ForegroundColor Cyan

# ============================
# Function: Remove user from AD group
# ============================
function Remove-UserFromGroup {
    param (
        [string]$userId,
        [string]$groupName
    )

    $userObj = Get-ADUser -Identity $userId -ErrorAction SilentlyContinue
    if (-not $userObj) {
        Write-Host "❌ User '$userId' not found in AD" -ForegroundColor Red
        return
    }

    try {
        Remove-ADGroupMember -Identity $groupName -Members $userObj -Confirm:$false -ErrorAction Stop
        Write-Host "✅ Removed '$userId' from '$groupName'" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to remove '$userId' from '$groupName': $_" -ForegroundColor Red
    }
}

# ============================
# Remove users from AD groups
# ============================
foreach ($user in $listPrimary) {
    Remove-UserFromGroup -userId $user.sAMAccountName -groupName $primaryGroup
}

foreach ($user in $listSecondary) {
    Remove-UserFromGroup -userId $user.sAMAccountName -groupName $secondaryGroup
}

Write-Host "`n✅ Removal process complete.`n" -ForegroundColor Cyan
