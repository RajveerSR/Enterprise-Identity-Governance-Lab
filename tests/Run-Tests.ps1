[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\IdentityGovernanceLab.psd1') -Force
$root = Split-Path -Parent $PSScriptRoot
$data = Import-LabData `
    -EmployeePath (Join-Path $root 'config\employees.csv') `
    -ConfigurationPath (Join-Path $root 'config\organisation.json') `
    -CurrentStatePath (Join-Path $root 'config\current-state.example.json')

$passed = 0
$failed = 0
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function New-TestGraphException {
    param([AllowNull()]$StatusCode, [AllowNull()][string]$ApiCode, [string]$Message = 'opaque Graph failure')
    $exception = New-Object System.Exception $Message
    if ($null -ne $StatusCode) { $exception | Add-Member -NotePropertyName ResponseStatusCode -NotePropertyValue $StatusCode }
    if ($ApiCode) { $exception | Add-Member -NotePropertyName Error -NotePropertyValue ([pscustomobject]@{ Code = $ApiCode }) }
    $exception
}
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try { & $Body; $script:passed++; Write-Host "PASS $Name" -ForegroundColor Green }
    catch { $script:failed++; Write-Host "FAIL $Name - $($_.Exception.Message)" -ForegroundColor Red }
}

Test-Case 'plans joiner, mover, and leaver changes' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    Assert-True ($plan.summary.CreateUser -eq 2) 'Expected two joiners.'
    Assert-True ($plan.summary.DisableUser -eq 1) 'Expected one leaver disable.'
    Assert-True ($plan.summary.RevokeSignInSessions -eq 1) 'Expected one session revocation.'
    Assert-True (@($plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'RemoveGroupMember' -and $_.groupKey -eq 'finance' }).Count -eq 1) 'Mover must lose Finance.'
    Assert-True (@($plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'AddGroupMember' -and $_.groupKey -eq 'engineering' }).Count -eq 1) 'Mover must gain Engineering.'
    Assert-True (@($plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.groupKey -eq 'external-project-x' }).Count -eq 0) 'Externally managed access must not be touched.'
}

Test-Case 'rejects duplicate employee IDs before planning' {
    $duplicate = @($data.Employees) + @($data.Employees | Select-Object -First 1)
    $threw = $false
    try { $null = New-LabAccessPlan -Employees $duplicate -Configuration $data.Configuration -CurrentState $data.CurrentState } catch { $threw = $_.Exception.Message -like '*Duplicate EmployeeId*' }
    Assert-True $threw 'Duplicate EmployeeId was not rejected.'
}

Test-Case 'rejects unknown departments before planning' {
    $employees = @($data.Employees | ForEach-Object { $_.PSObject.Copy() })
    $employees[0].Department = 'Unmapped Department'
    $threw = $false
    try { $null = New-LabAccessPlan -Employees $employees -Configuration $data.Configuration -CurrentState $data.CurrentState } catch { $threw = $_.Exception.Message -like '*Unknown department*' }
    Assert-True $threw 'Unknown department was not rejected.'
}

Test-Case 'rejects a joiner UPN outside the configured namespace' {
    $employees = @($data.Employees | ForEach-Object { $_.PSObject.Copy() })
    $employees[-1].UserPrincipalName = 'someone@example.net'
    $threw = $false
    try { $null = New-LabAccessPlan -Employees $employees -Configuration $data.Configuration -CurrentState $data.CurrentState } catch { $threw = $_.Exception.Message -like '*outside the lab scope or protected*' }
    Assert-True $threw 'Out-of-scope joiner UPN was not rejected.'
}

Test-Case 'converged repeated run produces no changes' {
    $converged = Get-Content -LiteralPath (Join-Path $root 'config\converged-state.example.json') -Raw | ConvertFrom-Json
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $converged
    Assert-True (@($plan.operations).Count -eq 0) 'A converged state should produce an empty plan.'
}

Test-Case 'continues independent work after partial failure' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $executor = {
        param($operation, $runtime)
        if ($operation.type -eq 'UpdateUser') { throw 'simulated Graph 503' }
        if ($operation.type -eq 'CreateUser') { return [pscustomobject]@{ resolvedUserId = "mock-$($operation.employeeId)" } }
        [pscustomobject]@{ message = 'mock success' }
    }
    $result = Invoke-LabPlan -Plan $plan -Executor $executor
    $diagnostic = (@($result.results) | ForEach-Object { "$($_.type):$($_.status)" }) -join ', '
    Assert-True ($result.failed -eq 1) "Expected exactly one simulated failure; received $($result.failed). Results: $diagnostic"
    Assert-True ($result.succeeded -gt 1) 'Independent operations should continue.'
}

Test-Case 'skips dependent grants when user creation fails' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $executor = {
        param($operation, $runtime)
        if ($operation.type -eq 'CreateUser' -and $operation.employeeId -eq 'E005') { throw 'simulated create failure' }
        if ($operation.type -eq 'CreateUser') { return [pscustomobject]@{ resolvedUserId = "mock-$($operation.employeeId)" } }
        [pscustomobject]@{ message = 'mock success' }
    }
    $result = Invoke-LabPlan -Plan $plan -Executor $executor
    Assert-True (@($result.results | Where-Object { $_.status -eq 'Skipped' }).Count -ge 1) 'Dependent operations were not skipped.'
}

Test-Case 'retains both joiner and joiner-manager creation dependencies' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $managerCreate = $plan.operations | Where-Object { $_.type -eq 'CreateUser' -and $_.employeeId -eq 'E005' }
    $employeeCreate = $plan.operations | Where-Object { $_.type -eq 'CreateUser' -and $_.employeeId -eq 'E006' }
    $setManager = $plan.operations | Where-Object { $_.type -eq 'SetManager' -and $_.employeeId -eq 'E006' }
    Assert-True (@($setManager.dependsOn) -contains $managerCreate.operationId) 'SetManager must depend on the new manager creation.'
    Assert-True (@($setManager.dependsOn) -contains $employeeCreate.operationId) 'SetManager must depend on the new employee creation.'
}

Test-Case 'replacement access depends on all obsolete managed access removals' {
    $state = $data.CurrentState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    ($state.users | Where-Object employeeId -eq 'E002').groupKeys = @('all-employees', 'finance', 'operations', 'external-project-x')
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $state
    $removals = @($plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'RemoveGroupMember' })
    $replacement = $plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'AddGroupMember' -and $_.groupKey -eq 'engineering' }
    Assert-True ($removals.Count -eq 2) 'Expected two obsolete managed memberships.'
    foreach ($removal in $removals) {
        Assert-True (@($replacement.dependsOn) -contains $removal.operationId) "Replacement access did not depend on removal '$($removal.operationId)'."
    }
    Assert-True (@($plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.groupKey -eq 'external-project-x' }).Count -eq 0) 'Unmanaged access must remain untouched.'
}

Test-Case 'failed mover removal skips replacement while unrelated users continue' {
    $state = $data.CurrentState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    ($state.users | Where-Object employeeId -eq 'E002').groupKeys = @('all-employees', 'finance', 'operations', 'external-project-x')
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $state
    $failedRemoval = $plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'RemoveGroupMember' } | Select-Object -First 1
    $successfulRemoval = $plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'RemoveGroupMember' } | Select-Object -Last 1
    $replacement = $plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'AddGroupMember' }
    $unrelated = $plan.operations | Where-Object { $_.employeeId -eq 'E005' -and $_.type -eq 'CreateUser' }
    $executor = {
        param($operation, $runtime)
        if ($operation.operationId -eq $failedRemoval.operationId) { throw 'simulated stale-access removal failure' }
        if ($operation.type -eq 'CreateUser') { return [pscustomobject]@{ resolvedUserId = "mock-$($operation.employeeId)" } }
        [pscustomobject]@{ message = 'mock success' }
    }
    $result = Invoke-LabPlan -Plan $plan -Executor $executor
    Assert-True (($result.results | Where-Object operationId -eq $failedRemoval.operationId).status -eq 'Failed') 'The simulated removal failure was not recorded.'
    Assert-True (($result.results | Where-Object operationId -eq $successfulRemoval.operationId).status -eq 'Succeeded') 'The other obsolete removal should still be attempted.'
    Assert-True (($result.results | Where-Object operationId -eq $replacement.operationId).status -eq 'Skipped') 'Replacement access should be skipped after any obsolete removal fails.'
    Assert-True (($result.results | Where-Object operationId -eq $unrelated.operationId).status -eq 'Succeeded') 'Unrelated users should continue.'
}

Test-Case 'refreshed mover state produces only outstanding transition work' {
    $state = $data.CurrentState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $mover = $state.users | Where-Object employeeId -eq 'E002'
    $mover.groupKeys = @('all-employees', 'finance', 'external-project-x')
    $mover.department = 'Engineering'
    $mover.managerEmployeeId = 'E004'
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $state
    $removal = $plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'RemoveGroupMember' }
    $replacement = $plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.type -eq 'AddGroupMember' }
    Assert-True (@($removal).Count -eq 1 -and $removal.groupKey -eq 'finance') 'Re-plan should retain only the failed Finance removal.'
    Assert-True (@($replacement.dependsOn) -contains $removal.operationId) 'Re-planned replacement must depend on the outstanding removal.'
    Assert-True (@($plan.operations | Where-Object { $_.employeeId -eq 'E002' -and $_.groupKey -eq 'operations' }).Count -eq 0) 'Completed Operations removal should disappear after refresh.'
}

Test-Case 'leaver disable failure continues containment and fails overall' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $leaverOperations = @($plan.operations | Where-Object employeeId -eq 'E003')
    $disable = $leaverOperations | Where-Object type -eq 'DisableUser'
    $executor = {
        param($operation, $runtime)
        if ($operation.operationId -eq $disable.operationId) { throw 'simulated disable failure' }
        if ($operation.type -eq 'CreateUser') { return [pscustomobject]@{ resolvedUserId = "mock-$($operation.employeeId)" } }
        [pscustomobject]@{ message = 'mock success' }
    }
    $result = Invoke-LabPlan -Plan $plan -Executor $executor
    Assert-True ($result.status -eq 'Failed' -and $result.failed -eq 1) 'Partial offboarding must fail overall.'
    foreach ($operation in @($leaverOperations | Where-Object type -ne 'DisableUser')) {
        Assert-True (($result.results | Where-Object operationId -eq $operation.operationId).status -eq 'Succeeded') "Leaver containment '$($operation.type)' did not continue."
    }
}

Test-Case 'leaver revocation failure still removes managed access and fails overall' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $revoke = $plan.operations | Where-Object { $_.employeeId -eq 'E003' -and $_.type -eq 'RevokeSignInSessions' }
    $removals = @($plan.operations | Where-Object { $_.employeeId -eq 'E003' -and $_.type -eq 'RemoveGroupMember' })
    $executor = {
        param($operation, $runtime)
        if ($operation.operationId -eq $revoke.operationId) { throw 'simulated revocation failure' }
        if ($operation.type -eq 'CreateUser') { return [pscustomobject]@{ resolvedUserId = "mock-$($operation.employeeId)" } }
        [pscustomobject]@{ message = 'mock success' }
    }
    $result = Invoke-LabPlan -Plan $plan -Executor $executor
    Assert-True ($result.status -eq 'Failed' -and $result.failed -eq 1) 'Revocation failure must fail offboarding overall.'
    foreach ($removal in $removals) {
        Assert-True (($result.results | Where-Object operationId -eq $removal.operationId).status -eq 'Succeeded') 'Managed access removal did not continue after revocation failure.'
    }
}

Test-Case 'StopOnFailure halts after the first leaver failure' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $disable = $plan.operations | Where-Object { $_.employeeId -eq 'E003' -and $_.type -eq 'DisableUser' }
    $calls = [Collections.Generic.List[string]]::new()
    $executor = {
        param($operation, $runtime)
        $calls.Add([string]$operation.operationId)
        if ($operation.operationId -eq $disable.operationId) { throw 'simulated disable failure' }
        [pscustomobject]@{ message = 'unexpected success' }
    }
    $result = Invoke-LabPlan -Plan $plan -Executor $executor -StopOnFailure
    Assert-True ($result.status -eq 'Failed' -and $result.failed -eq 1) 'Stopped execution must report failure.'
    Assert-True ($calls.Count -eq 1) 'StopOnFailure should stop immediately after the first operation fails.'
}

Test-Case 'refuses an account marked outside lab scope' {
    $employees = @($data.Employees | ForEach-Object { $_.PSObject.Copy() })
    $state = $data.CurrentState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $state.users[0].labManaged = $false
    $threw = $false
    try { $null = New-LabAccessPlan -Employees $employees -Configuration $data.Configuration -CurrentState $state } catch { $threw = $_.Exception.Message -like '*outside the lab scope or protected*' }
    Assert-True $threw 'Out-of-scope collision was not refused.'
}

Test-Case 'refuses a protected emergency-access account even if mislabelled managed' {
    $employee = $data.Employees[0].PSObject.Copy()
    $employee.EmployeeId = 'BREAKGLASS01'
    $employee.UserPrincipalName = 'breakglass-admin1@northstarlab.onmicrosoft.com'
    $employee.Status = 'Leaver'
    $employee.Department = 'Operations'
    $state = $data.CurrentState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $state.users[-1].labManaged = $true
    $threw = $false
    try { $null = New-LabAccessPlan -Employees @($employee) -Configuration $data.Configuration -CurrentState $state } catch { $threw = $_.Exception.Message -like '*outside the lab scope or protected*' }
    Assert-True $threw 'Protected emergency account was not refused.'
}

Test-Case 'rejects a UPN collision with a different directory identity' {
    $state = $data.CurrentState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $collision = $state.users[0].PSObject.Copy()
    $collision.id = '20000000-0000-0000-0000-000000000099'
    $collision.employeeId = 'SOMEONE-ELSE'
    $collision.userPrincipalName = 'eigl-ethan.jones@northstarlab.onmicrosoft.com'
    $collision.labManaged = $false
    $state.users = @($state.users) + $collision
    $threw = $false
    try { $null = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $state } catch { $threw = $_.Exception.Message -like '*UPN is already used*' }
    Assert-True $threw 'UPN collision was not rejected.'
}

Test-Case 'detects plan tampering' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $plan.operations[0].reason = 'tampered'
    Assert-True (-not (Test-LabPlanIntegrity -Plan $plan)) 'Tampered plan passed integrity validation.'
}

Test-Case 'detects tenant metadata tampering' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $plan.tenantId = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
    Assert-True (-not (Test-LabPlanIntegrity -Plan $plan)) 'Tenant ID tampering passed integrity validation.'
}

Test-Case 'detects mode metadata tampering' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $plan.mode = 'Apply'
    Assert-True (-not (Test-LabPlanIntegrity -Plan $plan)) 'Mode tampering passed integrity validation.'
}

Test-Case 'requires managedUserObjectIds to be present and an array' {
    foreach ($invalidValue in @('__MISSING__', $null, '20000000-0000-0000-0000-000000000001')) {
        $configuration = $data.Configuration | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        if ($invalidValue -eq '__MISSING__') {
            $configuration.scope.PSObject.Properties.Remove('managedUserObjectIds')
        }
        else {
            $configuration.scope.managedUserObjectIds = $invalidValue
        }
        $threw = $false
        try { $null = New-LabAccessPlan -Employees $data.Employees -Configuration $configuration -CurrentState $data.CurrentState } catch { $threw = $_.Exception.Message -like '*managedUserObjectIds*' }
        Assert-True $threw "Invalid managedUserObjectIds value '$invalidValue' was not rejected."
    }
}

Test-Case 'allows a joiner plan with an explicit empty managed user array' {
    $configuration = $data.Configuration | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $configuration.scope.managedUserObjectIds = @()
    $state = [pscustomobject]@{ schemaVersion = 1; source = 'empty synthetic state'; users = @() }
    $employee = $data.Employees | Where-Object EmployeeId -eq 'E001'
    $plan = New-LabAccessPlan -Employees @($employee) -Configuration $configuration -CurrentState $state
    Assert-True (@($plan.operations | Where-Object type -eq 'CreateUser').Count -eq 1) 'Explicit empty existing-user scope should still allow a controlled joiner.'
}

Test-Case 'apply boundary rejects malformed scope and protected targets' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $missingScope = $data.Configuration | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $missingScope.scope.PSObject.Properties.Remove('managedUserObjectIds')
    $malformedThrew = $false
    try { Assert-LabPlanScope -Plan $plan -Configuration $missingScope } catch { $malformedThrew = $_.Exception.Message -like '*managedUserObjectIds*' }
    Assert-True $malformedThrew 'Apply-boundary validation accepted a missing managed-user allowlist.'

    $protectedPlan = $plan | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $protectedPlan.operations[0].targetUserPrincipalName = 'breakglass-admin1@northstarlab.onmicrosoft.com'
    $protectedPlan.integrity.value = Get-LabPlanHash -Plan $protectedPlan
    Assert-True (Test-LabPlanIntegrity -Plan $protectedPlan) 'Protected-target test plan should have a valid change-detection hash.'
    $protectedThrew = $false
    try { Assert-LabPlanScope -Plan $protectedPlan -Configuration $data.Configuration } catch { $protectedThrew = $_.Exception.Message -like '*protected or out-of-scope*' }
    Assert-True $protectedThrew 'Apply-boundary validation accepted an emergency-access target.'
}

Test-Case 'plan integrity survives a JSON file round trip' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $roundTrip = $plan | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    Assert-True (Test-LabPlanIntegrity -Plan $roundTrip) 'Serialized plan did not retain its operation hash.'
}

Test-Case 'plan integrity supports zero and one operation JSON round trips' {
    $converged = Get-Content -LiteralPath (Join-Path $root 'config\converged-state.example.json') -Raw | ConvertFrom-Json
    $zeroPlan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $converged
    $zeroRoundTrip = $zeroPlan | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    Assert-True (Test-LabPlanIntegrity -Plan $zeroRoundTrip) 'Zero-operation plan failed after serialization.'

    $onePlan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $onePlan.operations = @($onePlan.operations[0])
    $onePlan.integrity.value = Get-LabPlanHash -Plan $onePlan
    $oneRoundTrip = $onePlan | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    Assert-True (Test-LabPlanIntegrity -Plan $oneRoundTrip) 'One-operation plan failed after serialization.'
}

Test-Case 'rejects unsupported plan and integrity payload versions' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $plan.schemaVersion = 999
    $plan.integrity.value = Get-LabPlanHash -Plan $plan
    Assert-True (-not (Test-LabPlanIntegrity -Plan $plan)) 'Unsupported plan schema version was accepted.'

    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $plan.integrity.payloadVersion = 999
    $plan.integrity.value = Get-LabPlanHash -Plan $plan
    Assert-True (-not (Test-LabPlanIntegrity -Plan $plan)) 'Unsupported integrity payload version was accepted.'
}

Test-Case 'rejects missing, forward, and tampered dependencies' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $dependent = $plan.operations | Where-Object { @($_.dependsOn).Count -gt 0 } | Select-Object -First 1
    $dependent.dependsOn = @('op-does-not-exist')
    $plan.integrity.value = Get-LabPlanHash -Plan $plan
    Assert-True (-not (Test-LabPlanIntegrity -Plan $plan)) 'Missing dependency was accepted.'

    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $plan.operations[0].dependsOn = @($plan.operations[-1].operationId)
    $plan.integrity.value = Get-LabPlanHash -Plan $plan
    Assert-True (-not (Test-LabPlanIntegrity -Plan $plan)) 'Forward dependency was accepted.'

    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $dependent = $plan.operations | Where-Object { @($_.dependsOn).Count -gt 0 } | Select-Object -First 1
    $dependent.dependsOn = @()
    Assert-True (-not (Test-LabPlanIntegrity -Plan $plan)) 'Dependency tampering passed hash validation.'
}

Test-Case 'classifies only structured Graph not-found errors as absence' {
    $http404 = New-TestGraphException -StatusCode 404 -ApiCode $null
    $apiNotFound = New-TestGraphException -StatusCode $null -ApiCode 'Request_ResourceNotFound'
    $messageOnly = New-TestGraphException -StatusCode $null -ApiCode $null -Message '404 Request_ResourceNotFound'
    $forbidden = New-TestGraphException -StatusCode 403 -ApiCode 'Authorization_RequestDenied'
    Assert-True (Test-LabGraphNotFoundError -ErrorObject $http404) 'Structured HTTP 404 was not classified as not found.'
    Assert-True (Test-LabGraphNotFoundError -ErrorObject $apiNotFound) 'Structured Graph resource-not-found code was not classified as not found.'
    Assert-True (-not (Test-LabGraphNotFoundError -ErrorObject $messageOnly)) 'Message-only 404 text must not be trusted.'
    Assert-True (-not (Test-LabGraphNotFoundError -ErrorObject $forbidden)) 'Permission denial must not be treated as absence.'
}

Test-Case 'exports a complete mocked snapshot across membership pagination' {
    $configuration = $data.Configuration | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $employee = $data.Employees | Where-Object EmployeeId -eq 'E001'
    $userId = '20000000-0000-0000-0000-000000000001'
    $firstGroupId = [string]$configuration.groups[0].id
    $calls = @{}
    $request = {
        param($method, $uri)
        $calls[$uri] = 1 + [int]$calls[$uri]
        if ($uri -eq 'https://mock.invalid/group-page-2') { return @{ value = @(@{ id = $userId }) } }
        if ($uri -like "*/groups/$firstGroupId/members*") { return @{ value = @(@{ id = 'unrelated-id' }); '@odata.nextLink' = 'https://mock.invalid/group-page-2' } }
        if ($uri -like '*/groups/*/members*') { return @{ value = @() } }
        if ($uri -like '*/manager?*') { throw (New-TestGraphException -StatusCode 404 -ApiCode 'Request_ResourceNotFound') }
        if ($uri -like '*/users/*') {
            return @{ id = $userId; employeeId = 'E001'; userPrincipalName = 'eigl-maya.chen@northstarlab.onmicrosoft.com'; displayName = 'Maya Chen'; jobTitle = 'Operations Director'; department = 'Operations'; accountEnabled = $true }
        }
        throw "Unexpected URI $uri"
    }
    $snapshot = Get-LabGraphStateSnapshot -Employees @($employee) -Configuration $configuration -TenantId 'mock-tenant' -RequestInvoker $request
    Assert-True (@($snapshot.users).Count -eq 1) 'Expected one exported user.'
    Assert-True (@($snapshot.users[0].groupKeys) -contains 'all-employees') 'Paginated membership was not included.'
    Assert-True ($calls['https://mock.invalid/group-page-2'] -eq 1) 'Next membership page was not requested exactly once.'
    Assert-True ($null -eq $snapshot.users[0].managerEmployeeId) 'A genuine manager 404 should produce no manager.'
}

Test-Case 'treats a structured user 404 as absent' {
    $employee = $data.Employees | Where-Object EmployeeId -eq 'E001'
    $request = {
        param($method, $uri)
        if ($uri -like '*/groups/*') { return @{ value = @() } }
        throw (New-TestGraphException -StatusCode 404 -ApiCode 'Request_ResourceNotFound')
    }
    $snapshot = Get-LabGraphStateSnapshot -Employees @($employee) -Configuration $data.Configuration -TenantId 'mock-tenant' -RequestInvoker $request
    Assert-True (@($snapshot.users).Count -eq 0) 'A genuine user 404 should be represented as absence.'
}

Test-Case 'keeps Graph permission authentication throttling service and connectivity failures visible' {
    $employee = $data.Employees | Where-Object EmployeeId -eq 'E001'
    $failures = @(
        @{ status = 401; code = 'InvalidAuthenticationToken'; message = 'authentication' },
        @{ status = 403; code = 'Authorization_RequestDenied'; message = 'permission' },
        @{ status = 429; code = 'TooManyRequests'; message = 'throttling' },
        @{ status = 503; code = 'ServiceUnavailable'; message = 'service' },
        @{ status = $null; code = $null; message = 'network unavailable' },
        @{ status = $null; code = $null; message = '404 Request_ResourceNotFound' }
    )
    foreach ($failure in $failures) {
        $request = {
            param($method, $uri)
            if ($uri -like '*/groups/*') { return @{ value = @() } }
            throw (New-TestGraphException -StatusCode $failure.status -ApiCode $failure.code -Message $failure.message)
        }
        $threw = $false
        try { $null = Get-LabGraphStateSnapshot -Employees @($employee) -Configuration $data.Configuration -TenantId 'mock-tenant' -RequestInvoker $request } catch { $threw = $true }
        Assert-True $threw "Graph failure '$($failure.message)' was suppressed into an incomplete snapshot."
    }
}

Test-Case 'keeps non-not-found manager failures visible' {
    $employee = $data.Employees | Where-Object EmployeeId -eq 'E001'
    $request = {
        param($method, $uri)
        if ($uri -like '*/groups/*') { return @{ value = @() } }
        if ($uri -like '*/manager?*') { throw (New-TestGraphException -StatusCode 403 -ApiCode 'Authorization_RequestDenied') }
        return @{ id = '20000000-0000-0000-0000-000000000001'; employeeId = 'E001'; userPrincipalName = 'eigl-maya.chen@northstarlab.onmicrosoft.com'; displayName = 'Maya Chen'; jobTitle = 'Operations Director'; department = 'Operations'; accountEnabled = $true }
    }
    $threw = $false
    try { $null = Get-LabGraphStateSnapshot -Employees @($employee) -Configuration $data.Configuration -TenantId 'mock-tenant' -RequestInvoker $request } catch { $threw = $true }
    Assert-True $threw 'Manager permission failure was suppressed into a misleading null manager.'
}

Write-Host "`n$passed passed; $failed failed"
if ($failed -gt 0) { exit 1 }
