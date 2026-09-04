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

if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) { throw "Tenant-specific configuration not found: $ConfigurationPath" }
if (-not (Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) { throw 'Import Microsoft.Graph.Authentication first.' }
$context = Get-MgContext
$configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
if (-not $context -or [string]$context.TenantId -ne [string]$configuration.tenant.tenantId) { throw 'Active Graph context does not match configuration.' }
$employees = @(Import-Csv -LiteralPath $EmployeePath)

$memberIdsByGroupKey = @{}
foreach ($group in @($configuration.groups | Where-Object labManaged)) {
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $uri = "https://graph.microsoft.com/v1.0/groups/$($group.id)/members?`$select=id"
    while ($uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri
        foreach ($member in @($page.value)) { $null = $ids.Add([string]$member.id) }
        $uri = [string]$page.'@odata.nextLink'
    }
    $memberIdsByGroupKey[[string]$group.key] = $ids
}

$users = [Collections.Generic.List[object]]::new()
$managedUserIds = @($configuration.scope.managedUserObjectIds | ForEach-Object { [string]$_ })
foreach ($employee in $employees) {
    $encodedUpn = [Uri]::EscapeDataString([string]$employee.UserPrincipalName)
    try {
        $user = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$encodedUpn`?`$select=id,employeeId,userPrincipalName,displayName,jobTitle,department,accountEnabled"
    }
    catch {
        if ($_.Exception.Message -match '404|Request_ResourceNotFound') { continue }
        throw
    }
    $groupKeys = @($memberIdsByGroupKey.Keys | Where-Object { $memberIdsByGroupKey[$_].Contains([string]$user.id) } | Sort-Object)
    $users.Add([pscustomobject][ordered]@{
        id = [string]$user.id
        employeeId = [string]$user.employeeId
        userPrincipalName = [string]$user.userPrincipalName
        displayName = [string]$user.displayName
        jobTitle = [string]$user.jobTitle
        department = [string]$user.department
        managerEmployeeId = $null
        accountEnabled = [bool]$user.accountEnabled
        labManaged = $managedUserIds -contains [string]$user.id
        sessionsRevokedAfterTermination = $false
        groupKeys = $groupKeys
    })
}

# Manager reads are delegated-only according to the current API permissions table.
$employeeIdByObjectId = @{}
foreach ($user in $users) { $employeeIdByObjectId[[string]$user.id] = [string]$user.employeeId }
foreach ($user in $users) {
    try {
        $manager = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)/manager?`$select=id"
        if ($manager -and $employeeIdByObjectId.ContainsKey([string]$manager.id)) { $user.managerEmployeeId = $employeeIdByObjectId[[string]$manager.id] }
    }
    catch {
        if ($_.Exception.Message -notmatch '404|Request_ResourceNotFound') { throw }
    }
}

$snapshot = [pscustomobject][ordered]@{
    schemaVersion = 1
    source = "Microsoft Graph tenant $($context.TenantId)"
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    users = @($users)
}
$snapshot | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Read-only snapshot written to $([IO.Path]::GetFullPath($OutputPath)). Review it before planning."
$snapshot
