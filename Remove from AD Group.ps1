<#
.SYNOPSIS
    Active Directory Cleanup Script for Workspace ONE Offboarding

.DESCRIPTION
    Reads a list of disabled users and their associated WS1 AD groups from a CSV file.
    Attempts to remove each user from the specified AD group, logging the result.

.REQUIREMENTS
    - PowerShell with RSAT: ActiveDirectory module
    - CSV formatted with 'User ID' and 'Group Membership' columns

.NOTES
    - Group membership names have been replaced with placeholders.
    - Store CSV files in a secured path and ensure account permissions before execution.

.AUTHOR
    Brian Irish
#>

# Import the Active Directory module
Import-Module ActiveDirectory

# Path to the CSV file
$userCsvPath = "C:\Path\To\WS1UserCleanup\AD_Removal\Disabled_Accounts_WS1Users.csv"

# Import the CSV
$userList = Import-Csv -Path $userCsvPath

# Iterate through each row in the CSV
foreach ($entry in $userList) {
    $userId = $entry.'User ID'
    $groupName = $entry.'Group Membership'

    # Validate that group name is one of the expected ones
    if ($groupName -notin @("WS1Group1", "WS1Group2")) {
        Write-Host "⚠️  Skipping '$userId': Unknown group '$groupName'" -ForegroundColor Yellow
        continue
    }

    # Attempt to retrieve the AD user
    $userObj = Get-ADUser -Identity $userId -ErrorAction SilentlyContinue
    if (-not $userObj) {
        Write-Host "❌ User '$userId' not found in AD" -ForegroundColor Red
        continue
    }

    # Attempt to remove user from specified group
    try {
        Remove-ADGroupMember -Identity $groupName -Members $userObj -Confirm:$false
        Write-Host "✅ Removed '$userId' from '$groupName'"
    } catch {
        Write-Host "❌ Failed to remove '$userId' from '$groupName': $_" -ForegroundColor Red
    }
}
