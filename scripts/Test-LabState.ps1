[CmdletBinding()]
param(
    [string]$EmployeePath,
    [string]$ConfigurationPath,
    [string]$CurrentStatePath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $EmployeePath) { $EmployeePath = Join-Path $repositoryRoot 'config\employees.csv' }
if (-not $ConfigurationPath) { $ConfigurationPath = Join-Path $repositoryRoot 'config\organisation.json' }
if (-not $CurrentStatePath) { $CurrentStatePath = Join-Path $repositoryRoot 'config\current-state.example.json' }
Import-Module (Join-Path $PSScriptRoot '..\src\IdentityGovernanceLab.psd1') -Force
$data = Import-LabData -EmployeePath $EmployeePath -ConfigurationPath $ConfigurationPath -CurrentStatePath $CurrentStatePath
$result = Test-LabAccessState -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
$result
if (-not $result.compliant) { exit 1 }
