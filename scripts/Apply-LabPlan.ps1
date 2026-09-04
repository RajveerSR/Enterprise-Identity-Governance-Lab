[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PlanPath,
    [string]$ConfigurationPath,
    [Parameter(Mandatory)][switch]$ConfirmTenantMutation,
    [string]$ResultPath,
    [switch]$StopOnFailure
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $ConfigurationPath) { $ConfigurationPath = Join-Path $repositoryRoot 'config\organisation.local.json' }
if (-not $ResultPath) { $ResultPath = Join-Path $repositoryRoot 'evidence\runs\latest-apply-result.json' }
Import-Module (Join-Path $PSScriptRoot '..\src\IdentityGovernanceLab.psd1') -Force

if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) {
    throw "A tenant-specific local configuration is required: $ConfigurationPath. See docs/setup.md."
}
$configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json

Assert-LabScopeConfiguration -Configuration $configuration
if (-not $ConfirmTenantMutation) { throw 'Explicit -ConfirmTenantMutation is required.' }
if (-not [bool]$configuration.tenant.allowMutation) { throw 'tenant.allowMutation is false. No Graph writes were attempted.' }
if ([string]$configuration.tenant.tenantId -eq '00000000-0000-0000-0000-000000000000') { throw 'Replace the placeholder tenant ID before applying.' }
if ([string]$plan.tenantId -ne [string]$configuration.tenant.tenantId) { throw 'Plan tenant ID does not match configuration.' }
if (-not (Test-LabPlanIntegrity -Plan $plan)) { throw 'Plan integrity check failed.' }
Assert-LabPlanScope -Plan $plan -Configuration $configuration

if (-not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {
    throw 'Microsoft.Graph.Authentication is not loaded. See docs/setup.md.'
}
$context = Get-MgContext
if (-not $context -or [string]$context.TenantId -ne [string]$configuration.tenant.tenantId) {
    throw 'The active Microsoft Graph context does not match the configured tenant.'
}

$executor = { param($operation, $runtimeUserIds) Invoke-LabGraphOperation -Operation $operation -RuntimeUserIds $runtimeUserIds }
$result = Invoke-LabPlan -Plan $plan -Executor $executor -StopOnFailure:$StopOnFailure
$resultDirectory = Split-Path -Parent $ResultPath
if (-not (Test-Path -LiteralPath $resultDirectory)) { New-Item -ItemType Directory -Path $resultDirectory | Out-Null }
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
$result
if ($result.failed -gt 0 -or $result.skipped -gt 0) { exit 1 }
