[CmdletBinding()]
param(
    [string]$ConfigurationPath,
    [string]$CurrentStatePath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $ConfigurationPath) { $ConfigurationPath = Join-Path $repositoryRoot 'config\organisation.json' }
if (-not $CurrentStatePath) { $CurrentStatePath = Join-Path $repositoryRoot 'config\current-state.example.json' }
if (-not $OutputPath) { $OutputPath = Join-Path $repositoryRoot 'evidence\runs\latest-cleanup-plan.json' }
Import-Module (Join-Path $PSScriptRoot '..\src\IdentityGovernanceLab.psd1') -Force
$configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
$state = Get-Content -LiteralPath $CurrentStatePath -Raw | ConvertFrom-Json

# Cleanup is intentionally deprovisioning, not deletion. It selects only resources
# already marked as lab-managed; the module independently enforces UPN scope/protection.
$employees = foreach ($user in @($state.users | Where-Object labManaged)) {
    [pscustomobject]@{
        EmployeeId = [string]$user.employeeId
        GivenName = ''
        Surname = ''
        DisplayName = [string]$user.displayName
        UserPrincipalName = [string]$user.userPrincipalName
        JobTitle = [string]$user.jobTitle
        Department = [string]$user.department
        ManagerEmployeeId = ''
        IsManager = 'false'
        Status = 'Leaver'
    }
}
$plan = New-LabAccessPlan -Employees @($employees) -Configuration $configuration -CurrentState $state
$plan | Add-Member -NotePropertyName cleanupPolicy -NotePropertyValue 'Disable, revoke, and remove managed memberships; do not delete users or groups.'
$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory | Out-Null }
$plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "CLEANUP PREVIEW ONLY - $(@($plan.operations).Count) proposed operation(s)."
$plan
