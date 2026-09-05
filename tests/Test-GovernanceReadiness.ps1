$ErrorActionPreference = 'Stop'
$tenant = 'd0000000-1111-4111-8111-111111111111'
$group = 'e0000000-1111-4111-8111-111111111111'
$scriptUnderTest = Join-Path $PSScriptRoot '../scripts/Export-GovernanceReadiness.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('iam-readiness-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
$global:IamReadinessTestCase = ''
$global:IamReadinessTestCalls = @()
function Get-MgContext {
    $id = if ($global:IamReadinessTestCase -eq 'wrong-tenant') { 'f0000000-1111-4111-8111-111111111111' } else { $tenant }
    [pscustomobject]@{ TenantId = $id; AuthType = 'Delegated' }
}
function Invoke-MgGraphRequest {
    param($Method, $Uri, $OutputType)
    if ($Method -ne 'GET') { throw 'Unexpected mutation method' }
    $global:IamReadinessTestCalls += $Uri
    if ($global:IamReadinessTestCase -eq 'permission-error' -and $Uri -match 'accessReviews') { throw 'HTTP 403 mocked permission error' }
    if ($global:IamReadinessTestCase -eq 'bad-pagination' -and $Uri -match 'subscribedSkus') {
        return [pscustomobject]@{ value = @(); '@odata.nextLink' = 'https://untrusted.example/steal' }
    }
    if ($global:IamReadinessTestCase -eq 'success' -and $Uri -match 'subscribedSkus') {
        return [pscustomobject]@{ value = @([pscustomobject]@{ id = 'first' }); '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/test-next' }
    }
    if ($Uri -match 'test-next') { return [pscustomobject]@{ value = @([pscustomobject]@{ id = 'second' }) } }
    return [pscustomobject]@{ value = @() }
}
$passed = 0
try {
    foreach ($name in @('wrong-tenant', 'success', 'permission-error', 'bad-pagination')) {
        $global:IamReadinessTestCase = $name; $global:IamReadinessTestCalls = @(); $thrown = $false
        $output = Join-Path $temp ($name + '.json')
        try { & $scriptUnderTest -ExpectedTenantId $tenant -FinanceGroupId $group -OutputPath $output }
        catch { $thrown = $true }
        if ($name -eq 'wrong-tenant') {
            if (-not $thrown -or $global:IamReadinessTestCalls.Count -ne 0 -or (Test-Path -LiteralPath $output)) { throw 'Wrong-tenant guard failed' }
        } else {
            $saved = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
            if ($name -eq 'success') {
                if ($thrown -or -not $saved.evidenceMetadata.complete -or @($saved.checks.licences.value).Count -ne 2) { throw 'Complete paginated read was not preserved' }
            } elseif (-not $thrown -or $saved.evidenceMetadata.complete) { throw 'Incomplete read was falsely successful' }
            if (@($global:IamReadinessTestCalls | Where-Object { $_ -like '*untrusted*' }).Count) { throw 'Followed untrusted pagination URL' }
        }
        $passed++
    }
    Write-Host "Governance readiness tests: $passed passed, 0 failed (mocked; no network)."
} finally {
    # Delete only these known test files; do not recursively delete any calculated directory.
    foreach ($name in @('wrong-tenant', 'success', 'permission-error', 'bad-pagination')) {
        $path = Join-Path $temp ($name + '.json')
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    Remove-Item -LiteralPath $temp
}
