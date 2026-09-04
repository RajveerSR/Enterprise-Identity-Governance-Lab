[CmdletBinding()]
param(
    [string]$EmployeePath,
    [string]$ConfigurationPath,
    [string]$CurrentStatePath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $EmployeePath) { $EmployeePath = Join-Path $repositoryRoot 'config\employees.csv' }
if (-not $ConfigurationPath) { $ConfigurationPath = Join-Path $repositoryRoot 'config\organisation.json' }
if (-not $CurrentStatePath) { $CurrentStatePath = Join-Path $repositoryRoot 'config\current-state.example.json' }
if (-not $OutputPath) { $OutputPath = Join-Path $repositoryRoot 'evidence\runs\latest-plan.json' }
Import-Module (Join-Path $PSScriptRoot '..\src\IdentityGovernanceLab.psd1') -Force

$data = Import-LabData -EmployeePath $EmployeePath -ConfigurationPath $ConfigurationPath -CurrentStatePath $CurrentStatePath
$plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}
$plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "PREVIEW ONLY - $(@($plan.operations).Count) proposed operation(s)."
$plan.summary | Format-List
Write-Host "Plan: $([IO.Path]::GetFullPath($OutputPath))"
$plan
