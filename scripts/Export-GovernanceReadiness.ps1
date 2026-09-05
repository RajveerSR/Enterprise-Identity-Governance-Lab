[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$ExpectedTenantId,
    [Parameter(Mandatory)][guid]$FinanceGroupId,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputPath) { throw 'Choose a new output path; existing evidence is not overwritten.' }
if (-not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) { throw 'Connect Microsoft.Graph.Authentication before exporting.' }
$context = Get-MgContext
if (-not $context -or $context.TenantId -ne $ExpectedTenantId.ToString() -or $context.AuthType -ne 'Delegated') {
    throw 'A delegated Microsoft Graph session in the expected tenant is required.'
}

function Read-CompleteGraphCollection([string]$Uri) {
    $items = @()
    do {
        if (-not $Uri.StartsWith('https://graph.microsoft.com/v1.0/')) { throw 'Unexpected Graph pagination origin.' }
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        if (-not $page.PSObject.Properties['value'] -or $null -eq $page.value -or $page.value -isnot [array]) {
            throw 'Graph response has no value array; refusing an incomplete collection.'
        }
        $items += @($page.value)
        $Uri = $page.'@odata.nextLink'
    } while ($Uri)
    return ,$items
}

$filter = [uri]::EscapeDataString("scopeId eq '/' and scopeType eq 'DirectoryRole'")
$queries = [ordered]@{
    licences = 'https://graph.microsoft.com/v1.0/subscribedSkus'
    roleDefinitions = 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions'
    eligibility = 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleInstances'
    activeAssignments = 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances'
    rolePolicies = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicyAssignments?`$filter=$filter&`$expand=policy(`$expand=rules)"
    accessReviews = 'https://graph.microsoft.com/v1.0/identityGovernance/accessReviews/definitions'
    financeOwners = "https://graph.microsoft.com/v1.0/groups/$FinanceGroupId/owners?`$select=id,displayName"
    financeMembers = "https://graph.microsoft.com/v1.0/groups/$FinanceGroupId/members?`$select=id,displayName"
}
$checks = [ordered]@{}
$failures = 0
foreach ($entry in $queries.GetEnumerator()) {
    try {
        $data = Read-CompleteGraphCollection $entry.Value
        $checks[$entry.Key] = [ordered]@{ succeeded = $true; value = @($data) }
        Write-Host "$($entry.Key): read successfully ($(@($data).Count) objects)"
    } catch {
        $failures++
        $checks[$entry.Key] = [ordered]@{ succeeded = $false; error = $_.Exception.Message }
        Write-Warning "$($entry.Key): unavailable; see private export."
    }
}
$result = [ordered]@{
    evidenceMetadata = [ordered]@{
        type = 'tenant-governance-readiness'; capturedAtUtc = [datetime]::UtcNow.ToString('o')
        tenantId = $ExpectedTenantId.ToString(); complete = ($failures -eq 0)
        interpretation = 'Read-only configuration inventory; does not prove activation, approval, review decisions or removal.'
    }
    checks = $checks
}
$parent = Split-Path -Parent $OutputPath
if ($parent) { [void](New-Item -ItemType Directory -Path $parent -Force) }
[IO.File]::WriteAllText($OutputPath, ($result | ConvertTo-Json -Depth 70), (New-Object Text.UTF8Encoding($false)))
if ($failures) { throw "$failures readiness checks failed; partial evidence saved with complete=false." }
Write-Host "Private readiness evidence saved: $OutputPath"
