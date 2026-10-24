param(
    [string]$ResourceGroup = "RG-FileServerLab",
    [string]$VMName = "FS01"
)

Write-Host "`n=== RBAC Lab Validation ===" -ForegroundColor Cyan

# FS01's resource ID is the scope of all three assignments
$vmId = az vm show -g $ResourceGroup -n $VMName --query id -o tsv 2>$null
if (-not $vmId) { throw "VM $VMName not found in $ResourceGroup. Confirm the NTFS lab is deployed." }
Write-Host "Scope: $vmId`n"

# Query the live role assignments on FS01
$assignments = az role assignment list --scope $vmId `
    --query "[].{role:roleDefinitionName,principal:principalName}" `
    -o json | ConvertFrom-Json

$expected = @(
    @{ Role = "Owner";                       Label = "SysAdmin" },
    @{ Role = "Virtual Machine Contributor"; Label = "SupportTech" },
    @{ Role = "Reader";                      Label = "Auditor" }
)

$allPass = $true
Write-Host "[ Role Assignment Validation ]"
foreach ($e in $expected) {
    $match = $assignments | Where-Object { $_.role -eq $e.Role }
    if ($match) {
        Write-Host "  [PASS] $($e.Role) -> $($match.principal)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $($e.Role) not found on $VMName" -ForegroundColor Red
        $allPass = $false
    }
}

# Reference table (static text, not a live check)
Write-Host "`n[ Permission Reference - FS01 scope only ]"
$matrix = @(
    @{ Action = "View VM details";   O = "Yes"; VC = "Yes"; R = "Yes" },
    @{ Action = "Start / Stop VM";   O = "Yes"; VC = "Yes"; R = "No" },
    @{ Action = "Connect via RDP";   O = "Yes"; VC = "Yes"; R = "No" },
    @{ Action = "Delete VM";         O = "Yes"; VC = "No";  R = "No" },
    @{ Action = "Manage RBAC roles"; O = "Yes"; VC = "No";  R = "No" }
)
Write-Host ("  {0,-26} {1,-8} {2,-20} {3}" -f "Action", "Owner", "VM Contributor", "Reader")
foreach ($row in $matrix) {
    Write-Host ("  {0,-26} {1,-8} {2,-20} {3}" -f $row.Action, $row.O, $row.VC, $row.R)
}

# Export a report for the record
$overall = if ($allPass) { "ALL PASS" } else { "FAILURES DETECTED" }
$report = "RBAC Lab Validation Report`nGenerated: $(Get-Date)`nResource Group: $ResourceGroup`nVM: $VMName`nVM Resource ID: $vmId`n`n"
$report += $assignments | Format-Table -AutoSize | Out-String
$report += "`nOverall: $overall"
$report | Out-File "./RBAC_Lab_Report.txt" -Encoding UTF8

Write-Host "`nReport exported: RBAC_Lab_Report.txt" -ForegroundColor Cyan
Write-Host "Overall: $overall" -ForegroundColor $(if ($allPass) { "Green" } else { "Red" })
