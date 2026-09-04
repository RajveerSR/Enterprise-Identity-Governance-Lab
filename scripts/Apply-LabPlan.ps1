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

if (-not $ConfirmTenantMutation) { throw 'Explicit -ConfirmTenantMutation is required.' }
if (-not [bool]$configuration.tenant.allowMutation) { throw 'tenant.allowMutation is false. No Graph writes were attempted.' }
if ([string]$configuration.tenant.tenantId -eq '00000000-0000-0000-0000-000000000000') { throw 'Replace the placeholder tenant ID before applying.' }
if ([string]$plan.tenantId -ne [string]$configuration.tenant.tenantId) { throw 'Plan tenant ID does not match configuration.' }
if (-not (Test-LabPlanIntegrity -Plan $plan)) { throw 'Plan integrity check failed.' }

# Recheck scope at the mutation boundary. The plan hash detects accidental edits;
# this allowlist protects against a deliberately regenerated but over-broad plan.
$protectedUpns = @($configuration.scope.protectedUserPrincipalNames | ForEach-Object { ([string]$_).ToLowerInvariant() })
$upnPrefix = ([string]$configuration.scope.userPrincipalNamePrefix).ToLowerInvariant()
$upnSuffix = '@' + ([string]$configuration.tenant.verifiedDomain).ToLowerInvariant()
$managedGroupIds = @($configuration.groups | Where-Object labManaged | ForEach-Object { [string]$_.id })
$managedUserIds = @($configuration.scope.managedUserObjectIds | ForEach-Object { [string]$_ })
foreach ($operation in @($plan.operations)) {
    $upn = ([string]$operation.targetUserPrincipalName).ToLowerInvariant()
    if ($protectedUpns -contains $upn -or -not $upn.EndsWith($upnSuffix) -or -not $upn.Split('@')[0].StartsWith($upnPrefix)) {
        throw "Operation '$($operation.operationId)' targets a protected or out-of-scope UPN."
    }
    if ($operation.groupId -and $managedGroupIds -notcontains [string]$operation.groupId) {
        throw "Operation '$($operation.operationId)' targets a group outside the managed allowlist."
    }
    if ($operation.targetUserId -and $managedUserIds -notcontains [string]$operation.targetUserId) {
        throw "Operation '$($operation.operationId)' targets a user object outside the managed allowlist."
    }
}

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
