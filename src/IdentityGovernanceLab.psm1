Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-LabData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EmployeePath,
        [Parameter(Mandatory)][string]$ConfigurationPath,
        [Parameter(Mandatory)][string]$CurrentStatePath
    )

    foreach ($path in @($EmployeePath, $ConfigurationPath, $CurrentStatePath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required input file was not found: $path"
        }
    }

    [pscustomobject]@{
        Employees     = @(Import-Csv -LiteralPath $EmployeePath)
        Configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
        CurrentState  = Get-Content -LiteralPath $CurrentStatePath -Raw | ConvertFrom-Json
    }
}

function Get-LabPlanHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Operations)

    $json = ConvertTo-Json -InputObject @($Operations) -Depth 20 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-NormalizedBoolean {
    param([Parameter(Mandatory)]$Value, [Parameter(Mandatory)][string]$FieldName)
    if ($Value -is [bool]) { return $Value }
    switch ([string]$Value) {
        'true'  { return $true }
        'false' { return $false }
        default { throw "Field '$FieldName' must be true or false; received '$Value'." }
    }
}

function Assert-LabInputs {
    param($Employees, $Configuration, $CurrentState)

    if (@($Employees).Count -eq 0) { throw 'Employee input is empty.' }
    if ([int]$Configuration.schemaVersion -ne 1) { throw 'Unsupported organisation configuration schemaVersion.' }
    if ([int]$CurrentState.schemaVersion -ne 1) { throw 'Unsupported current-state schemaVersion.' }

    $departmentNames = @{}
    foreach ($department in @($Configuration.departments)) {
        $departmentNames[[string]$department.name] = $true
    }
    $groupKeys = @{}
    $groupIds = @{}
    foreach ($group in @($Configuration.groups)) {
        if ($groupKeys.ContainsKey([string]$group.key)) { throw "Duplicate group key '$($group.key)' in configuration." }
        if ([string]::IsNullOrWhiteSpace([string]$group.id)) { throw "Group '$($group.key)' has no object ID." }
        if ($groupIds.ContainsKey([string]$group.id)) { throw "Duplicate group object ID '$($group.id)' in configuration." }
        $groupKeys[[string]$group.key] = $true
        $groupIds[[string]$group.id] = $true
    }
    foreach ($key in @($Configuration.baselineGroupKeys) + @($Configuration.managerGroupKey)) {
        if (-not $groupKeys.ContainsKey([string]$key)) { throw "Configuration references unknown group key '$key'." }
    }
    foreach ($department in @($Configuration.departments)) {
        foreach ($key in @($department.accessGroupKeys)) {
            if (-not $groupKeys.ContainsKey([string]$key)) { throw "Department '$($department.name)' references unknown group '$key'." }
        }
    }

    $employeeIds = @{}
    $employeesById = @{}
    $upns = @{}
    $protectedUpns = @($Configuration.scope.protectedUserPrincipalNames | ForEach-Object { ([string]$_).ToLowerInvariant() })
    $expectedUpnSuffix = '@' + ([string]$Configuration.tenant.verifiedDomain).ToLowerInvariant()
    $expectedUpnPrefix = ([string]$Configuration.scope.userPrincipalNamePrefix).ToLowerInvariant()
    foreach ($employee in @($Employees)) {
        foreach ($field in @('EmployeeId', 'DisplayName', 'UserPrincipalName', 'Department', 'Status')) {
            if ([string]::IsNullOrWhiteSpace([string]$employee.$field)) {
                throw "Employee input has an empty required field '$field'."
            }
        }
        $employeeKey = ([string]$employee.EmployeeId).ToLowerInvariant()
        $upnKey = ([string]$employee.UserPrincipalName).ToLowerInvariant()
        if ($employeeIds.ContainsKey($employeeKey)) { throw "Duplicate EmployeeId '$($employee.EmployeeId)'." }
        if ($upns.ContainsKey($upnKey)) { throw "Duplicate UserPrincipalName '$($employee.UserPrincipalName)'." }
        if ($protectedUpns -contains $upnKey -or -not $upnKey.EndsWith($expectedUpnSuffix) -or -not $upnKey.Split('@')[0].StartsWith($expectedUpnPrefix)) {
            throw "Refusing '$($employee.EmployeeId)': its UPN is outside the lab scope or protected."
        }
        $employeeIds[$employeeKey] = $true
        $employeesById[$employeeKey] = $employee
        $upns[$upnKey] = $true
        if (@('Active', 'Leaver') -notcontains [string]$employee.Status) {
            throw "Unknown status '$($employee.Status)' for '$($employee.EmployeeId)'."
        }
        if (-not $departmentNames.ContainsKey([string]$employee.Department)) {
            throw "Unknown department '$($employee.Department)' for '$($employee.EmployeeId)'."
        }
        $null = Get-NormalizedBoolean -Value $employee.IsManager -FieldName 'IsManager'
    }
    foreach ($employee in @($Employees)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$employee.ManagerEmployeeId)) {
            if (-not $employeeIds.ContainsKey(([string]$employee.ManagerEmployeeId).ToLowerInvariant())) {
                throw "Unknown manager EmployeeId '$($employee.ManagerEmployeeId)' for '$($employee.EmployeeId)'."
            }
            $manager = $employeesById[([string]$employee.ManagerEmployeeId).ToLowerInvariant()]
            if ([string]$manager.Status -ne 'Active') {
                throw "Manager '$($employee.ManagerEmployeeId)' for '$($employee.EmployeeId)' is not Active."
            }
        }
    }
}

function Test-IsLabManagedUser {
    param($User, $Configuration)

    $upn = ([string]$User.userPrincipalName).ToLowerInvariant()
    $protected = @($Configuration.scope.protectedUserPrincipalNames | ForEach-Object { ([string]$_).ToLowerInvariant() })
    if ($protected -contains $upn) { return $false }
    if (-not [bool]$User.labManaged) { return $false }
    if ($Configuration.scope.PSObject.Properties.Name -contains 'managedUserObjectIds') {
        if (@($Configuration.scope.managedUserObjectIds) -notcontains [string]$User.id) { return $false }
    }
    $expectedSuffix = '@' + ([string]$Configuration.tenant.verifiedDomain).ToLowerInvariant()
    $expectedPrefix = ([string]$Configuration.scope.userPrincipalNamePrefix).ToLowerInvariant()
    return $upn.EndsWith($expectedSuffix) -and $upn.Split('@')[0].StartsWith($expectedPrefix)
}

function Get-DesiredGroupKeys {
    param($Employee, $Configuration)

    $keys = [Collections.Generic.List[string]]::new()
    foreach ($key in @($Configuration.baselineGroupKeys)) { $keys.Add([string]$key) }
    $department = @($Configuration.departments) | Where-Object { $_.name -eq $Employee.Department } | Select-Object -First 1
    foreach ($key in @($department.accessGroupKeys)) { $keys.Add([string]$key) }
    if (Get-NormalizedBoolean -Value $Employee.IsManager -FieldName 'IsManager') {
        $keys.Add([string]$Configuration.managerGroupKey)
    }
    @($keys | Sort-Object -Unique)
}

function New-LabAccessPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Employees,
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)]$CurrentState
    )

    Assert-LabInputs -Employees $Employees -Configuration $Configuration -CurrentState $CurrentState

    $usersByEmployeeId = @{}
    $usersByUpn = @{}
    foreach ($user in @($CurrentState.users)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$user.employeeId)) {
            $key = ([string]$user.employeeId).ToLowerInvariant()
            if ($usersByEmployeeId.ContainsKey($key)) { throw "Current state has duplicate EmployeeId '$($user.employeeId)'." }
            $usersByEmployeeId[$key] = $user
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$user.userPrincipalName)) {
            $upnKey = ([string]$user.userPrincipalName).ToLowerInvariant()
            if ($usersByUpn.ContainsKey($upnKey)) { throw "Current state has duplicate UserPrincipalName '$($user.userPrincipalName)'." }
            $usersByUpn[$upnKey] = $user
        }
    }
    $groupsByKey = @{}
    foreach ($group in @($Configuration.groups)) { $groupsByKey[[string]$group.key] = $group }

    $operationDrafts = [Collections.Generic.List[object]]::new()
    function Add-Operation {
        param([string]$Type, [int]$Priority, $Employee, $User, [string]$GroupKey, $Properties, [string]$Reason, [string[]]$DependsOn)
        $sequence = $operationDrafts.Count + 1
        $group = if ($GroupKey) { $groupsByKey[$GroupKey] } else { $null }
        $operationDrafts.Add([pscustomobject][ordered]@{
            operationId = ('op-{0:d3}' -f $sequence)
            type = $Type
            priority = $Priority
            employeeId = [string]$Employee.EmployeeId
            targetUserId = if ($User) { [string]$User.id } else { $null }
            targetUserPrincipalName = [string]$Employee.UserPrincipalName
            groupKey = if ($GroupKey) { $GroupKey } else { $null }
            groupId = if ($group) { [string]$group.id } else { $null }
            properties = $Properties
            reason = $Reason
            dependsOn = @($DependsOn | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        })
    }

    foreach ($employee in @($Employees | Sort-Object EmployeeId)) {
        $employeeKey = ([string]$employee.EmployeeId).ToLowerInvariant()
        $user = if ($usersByEmployeeId.ContainsKey($employeeKey)) { $usersByEmployeeId[$employeeKey] } else { $null }

        $desiredUpnKey = ([string]$employee.UserPrincipalName).ToLowerInvariant()
        if ($usersByUpn.ContainsKey($desiredUpnKey) -and [string]$usersByUpn[$desiredUpnKey].employeeId -ne [string]$employee.EmployeeId) {
            throw "Refusing to create or reconcile '$($employee.EmployeeId)': its UPN is already used by a different directory identity."
        }
        if ($user -and ([string]$user.userPrincipalName).ToLowerInvariant() -ne $desiredUpnKey) {
            throw "Refusing to reconcile '$($employee.EmployeeId)': its existing UPN does not match the authoritative input."
        }

        if ($user -and -not (Test-IsLabManagedUser -User $user -Configuration $Configuration)) {
            throw "Refusing to reconcile '$($employee.EmployeeId)': the matching account '$($user.userPrincipalName)' is outside the lab scope or protected."
        }

        if ($employee.Status -eq 'Leaver') {
            if (-not $user) { continue }
            if ([bool]$user.accountEnabled) {
                Add-Operation -Type 'DisableUser' -Priority 10 -Employee $employee -User $user -Reason 'Leaver: block new sign-ins before access removal.'
            }
            if (-not [bool]$user.sessionsRevokedAfterTermination) {
                Add-Operation -Type 'RevokeSignInSessions' -Priority 20 -Employee $employee -User $user -Reason 'Leaver: invalidate refresh tokens and browser sessions.'
            }
            foreach ($key in @($user.groupKeys | Sort-Object)) {
                if ($groupsByKey.ContainsKey([string]$key) -and [bool]$groupsByKey[[string]$key].labManaged) {
                    Add-Operation -Type 'RemoveGroupMember' -Priority 30 -Employee $employee -User $user -GroupKey ([string]$key) -Reason 'Leaver: remove access owned by this lab.'
                }
            }
            continue
        }

        $createDependency = @()
        if (-not $user) {
            Add-Operation -Type 'CreateUser' -Priority 40 -Employee $employee -Properties ([pscustomobject][ordered]@{
                accountEnabled = $true
                displayName = [string]$employee.DisplayName
                givenName = [string]$employee.GivenName
                surname = [string]$employee.Surname
                mailNickname = ([string]$employee.UserPrincipalName).Split('@')[0]
                userPrincipalName = [string]$employee.UserPrincipalName
                employeeId = [string]$employee.EmployeeId
                jobTitle = [string]$employee.JobTitle
                department = [string]$employee.Department
            }) -Reason 'Joiner: create a scoped cloud-only identity.'
            $createDependency = @($operationDrafts[$operationDrafts.Count - 1].operationId)
        }
        else {
            $changes = [ordered]@{}
            foreach ($property in @('displayName', 'jobTitle', 'department')) {
                $employeeProperty = switch ($property) { 'displayName' { 'DisplayName' } 'jobTitle' { 'JobTitle' } 'department' { 'Department' } }
                if ([string]$user.$property -ne [string]$employee.$employeeProperty) { $changes[$property] = [string]$employee.$employeeProperty }
            }
            if (-not [bool]$user.accountEnabled) { $changes['accountEnabled'] = $true }
            if ($changes.Count -gt 0) {
                Add-Operation -Type 'UpdateUser' -Priority 40 -Employee $employee -User $user -Properties ([pscustomobject]$changes) -Reason 'Mover or correction: align identity attributes.'
            }
        }

        $desiredKeys = @(Get-DesiredGroupKeys -Employee $employee -Configuration $Configuration)
        $currentKeys = if ($user) { @($user.groupKeys) } else { @() }
        foreach ($key in @($currentKeys | Sort-Object)) {
            if (($desiredKeys -notcontains $key) -and $groupsByKey.ContainsKey([string]$key) -and [bool]$groupsByKey[[string]$key].labManaged) {
                Add-Operation -Type 'RemoveGroupMember' -Priority 30 -Employee $employee -User $user -GroupKey ([string]$key) -Reason 'Mover: remove obsolete lab-managed access.'
            }
        }
        foreach ($key in @($desiredKeys | Sort-Object)) {
            if ($currentKeys -notcontains $key) {
                Add-Operation -Type 'AddGroupMember' -Priority 50 -Employee $employee -User $user -GroupKey ([string]$key) -DependsOn $createDependency -Reason 'Joiner or mover: grant access from the approved matrix.'
            }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$employee.ManagerEmployeeId)) {
            $managerChanged = (-not $user) -or ([string]$user.managerEmployeeId -ne [string]$employee.ManagerEmployeeId)
            if ($managerChanged) {
                $managerKey = ([string]$employee.ManagerEmployeeId).ToLowerInvariant()
                $managerUserId = if ($usersByEmployeeId.ContainsKey($managerKey)) { [string]$usersByEmployeeId[$managerKey].id } else { $null }
                $managerProperties = [pscustomobject]@{ managerEmployeeId = [string]$employee.ManagerEmployeeId; managerUserId = $managerUserId }
                Add-Operation -Type 'SetManager' -Priority 60 -Employee $employee -User $user -Properties $managerProperties -DependsOn $createDependency -Reason 'Align the manager relationship used by governance workflows.'
            }
        }
    }

    foreach ($operation in @($operationDrafts | Where-Object type -eq 'SetManager')) {
        $managerCreate = @($operationDrafts | Where-Object {
            $_.type -eq 'CreateUser' -and $_.employeeId -eq [string]$operation.properties.managerEmployeeId
        } | Select-Object -First 1)
        if ($managerCreate.Count -gt 0) {
            $operation.dependsOn = @(@($operation.dependsOn) + [string]$managerCreate[0].operationId | Sort-Object -Unique)
        }
    }

    $operations = @($operationDrafts | Sort-Object priority, employeeId, operationId)
    $summary = [ordered]@{}
    foreach ($type in @('CreateUser','UpdateUser','DisableUser','RevokeSignInSessions','AddGroupMember','RemoveGroupMember','SetManager')) {
        $summary[$type] = @($operations | Where-Object type -eq $type).Count
    }
    [pscustomobject][ordered]@{
        schemaVersion = 1
        mode = 'Preview'
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        tenantId = [string]$Configuration.tenant.tenantId
        source = [string]$CurrentState.source
        summary = [pscustomobject]$summary
        operations = $operations
        contentHash = Get-LabPlanHash -Operations $operations
        warnings = @(
            'Preview only: no tenant mutation has occurred.',
            'Only direct membership in configured lab-managed groups is reconciled.',
            'Synthetic snapshots and outputs are not tenant evidence.'
        )
    }
}

function Test-LabPlanIntegrity {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan)
    if ([int]$Plan.schemaVersion -ne 1) { return $false }
    $actual = Get-LabPlanHash -Operations @($Plan.operations)
    return $actual -eq [string]$Plan.contentHash
}

function Invoke-LabPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Plan,
        [Parameter(Mandatory)][scriptblock]$Executor,
        [switch]$StopOnFailure
    )
    if (-not (Test-LabPlanIntegrity -Plan $Plan)) { throw 'Plan integrity validation failed. Regenerate the plan.' }

    $results = [Collections.Generic.List[object]]::new()
    $runtimeUserIds = @{}
    $statusByOperation = @{}
    foreach ($operation in @($Plan.operations)) {
        $blockedBy = @($operation.dependsOn | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_) -and $statusByOperation[[string]$_] -ne 'Succeeded'
        })
        if ($blockedBy.Count -gt 0) {
            $statusByOperation[[string]$operation.operationId] = 'Skipped'
            $results.Add([pscustomobject]@{ operationId = $operation.operationId; type = $operation.type; status = 'Skipped'; message = "Dependency did not succeed: $($blockedBy -join ', ')" })
            continue
        }
        try {
            $response = & $Executor $operation $runtimeUserIds
            if ($null -eq $response) { $response = [pscustomobject]@{} }
            if ($response.PSObject.Properties.Name -contains 'resolvedUserId' -and $response.resolvedUserId) {
                $runtimeUserIds[[string]$operation.employeeId] = [string]$response.resolvedUserId
            }
            $message = if ($response.PSObject.Properties.Name -contains 'message') { [string]$response.message } else { '' }
            $statusByOperation[[string]$operation.operationId] = 'Succeeded'
            $results.Add([pscustomobject]@{ operationId = $operation.operationId; type = $operation.type; status = 'Succeeded'; message = $message })
        }
        catch {
            $statusByOperation[[string]$operation.operationId] = 'Failed'
            $results.Add([pscustomobject]@{ operationId = $operation.operationId; type = $operation.type; status = 'Failed'; message = $_.Exception.Message })
            if ($StopOnFailure) { break }
        }
    }
    [pscustomobject][ordered]@{
        planHash = [string]$Plan.contentHash
        executedAtUtc = [DateTime]::UtcNow.ToString('o')
        succeeded = @($results | Where-Object status -eq 'Succeeded').Count
        failed = @($results | Where-Object status -eq 'Failed').Count
        skipped = @($results | Where-Object status -eq 'Skipped').Count
        results = @($results)
    }
}

function New-TemporaryLabPassword {
    $bytes = New-Object byte[] 24
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    'Eigl!' + [Convert]::ToBase64String($bytes).Replace('/', '7').Replace('+', '8').Substring(0, 20)
}

function Invoke-LabGraphOperation {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Operation, [Parameter(Mandatory)][hashtable]$RuntimeUserIds)

    if (-not (Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required. Install/import it and connect before applying.'
    }
    $userId = if ($Operation.targetUserId) { [string]$Operation.targetUserId } else { [string]$RuntimeUserIds[[string]$Operation.employeeId] }
    switch ([string]$Operation.type) {
        'CreateUser' {
            $body = [ordered]@{}
            foreach ($property in $Operation.properties.PSObject.Properties) { $body[$property.Name] = $property.Value }
            $body.passwordProfile = @{ forceChangePasswordNextSignIn = $true; password = New-TemporaryLabPassword }
            $created = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/users' -Body ($body | ConvertTo-Json -Depth 10) -ContentType 'application/json'
            return [pscustomobject]@{ resolvedUserId = [string]$created.id; message = 'User created; temporary password was not logged.' }
        }
        'UpdateUser' {
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$userId" -Body ($Operation.properties | ConvertTo-Json -Depth 10) -ContentType 'application/json' | Out-Null
        }
        'DisableUser' {
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$userId" -Body '{"accountEnabled":false}' -ContentType 'application/json' | Out-Null
        }
        'RevokeSignInSessions' {
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$userId/revokeSignInSessions" -Body '{}' -ContentType 'application/json' | Out-Null
        }
        'AddGroupMember' {
            $body = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$userId" } | ConvertTo-Json
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$($Operation.groupId)/members/`$ref" -Body $body -ContentType 'application/json' | Out-Null
        }
        'RemoveGroupMember' {
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$($Operation.groupId)/members/$userId/`$ref" | Out-Null
        }
        'SetManager' {
            $managerId = if ($Operation.properties.managerUserId) { [string]$Operation.properties.managerUserId } else { [string]$RuntimeUserIds[[string]$Operation.properties.managerEmployeeId] }
            if (-not $managerId) { throw "Manager '$($Operation.properties.managerEmployeeId)' has no resolvable user ID." }
            $body = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$managerId" } | ConvertTo-Json
            Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/v1.0/users/$userId/manager/`$ref" -Body $body -ContentType 'application/json' | Out-Null
        }
        default { throw "Unsupported operation type '$($Operation.type)'." }
    }
    [pscustomobject]@{ message = 'Microsoft Graph operation completed.' }
}

function Test-LabAccessState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Employees,
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)]$CurrentState
    )
    $plan = New-LabAccessPlan -Employees $Employees -Configuration $Configuration -CurrentState $CurrentState
    [pscustomobject]@{
        compliant = @($plan.operations).Count -eq 0
        differenceCount = @($plan.operations).Count
        differences = @($plan.operations)
    }
}

Export-ModuleMember -Function Import-LabData, New-LabAccessPlan, Get-LabPlanHash, Test-LabPlanIntegrity, Invoke-LabPlan, Invoke-LabGraphOperation, Test-LabAccessState
