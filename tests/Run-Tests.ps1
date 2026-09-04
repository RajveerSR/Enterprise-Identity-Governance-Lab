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

Test-Case 'plan integrity survives a JSON file round trip' {
    $plan = New-LabAccessPlan -Employees $data.Employees -Configuration $data.Configuration -CurrentState $data.CurrentState
    $roundTrip = $plan | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    Assert-True (Test-LabPlanIntegrity -Plan $roundTrip) 'Serialized plan did not retain its operation hash.'
}

Write-Host "`n$passed passed; $failed failed"
if ($failed -gt 0) { exit 1 }
