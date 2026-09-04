[CmdletBinding()]
param(
    [string]$EmployeePath,
    [string]$ConfigurationPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $EmployeePath) { $EmployeePath = Join-Path $repositoryRoot 'config\employees.csv' }
if (-not $ConfigurationPath) { $ConfigurationPath = Join-Path $repositoryRoot 'config\organisation.local.json' }
if (-not $OutputPath) { $OutputPath = Join-Path $repositoryRoot 'config\current-state.local.json' }

Import-Module (Join-Path $repositoryRoot 'src\IdentityGovernanceLab.psd1') -Force
if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) { throw "Tenant-specific configuration not found: $ConfigurationPath" }
if (-not (Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) { throw 'Import Microsoft.Graph.Authentication first.' }
$context = Get-MgContext
$configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
if (-not $context -or [string]$context.TenantId -ne [string]$configuration.tenant.tenantId) { throw 'Active Graph context does not match configuration.' }
$employees = @(Import-Csv -LiteralPath $EmployeePath)
$requestInvoker = { param($method, $uri) Invoke-MgGraphRequest -Method $method -Uri $uri }
$snapshot = Get-LabGraphStateSnapshot -Employees $employees -Configuration $configuration -TenantId ([string]$context.TenantId) -RequestInvoker $requestInvoker
$snapshot | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Read-only snapshot written to $([IO.Path]::GetFullPath($OutputPath)). Review it before planning."
$snapshot
