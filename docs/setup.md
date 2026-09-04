# Setup

## Local-only workflow

No modules or tenant are required:

```powershell
./scripts/Invoke-Tests.ps1
./scripts/New-LabPlan.ps1
```

Inspect `evidence/runs/latest-plan.json`. It is ignored and labelled preview-only.

## Prepare the first read-only tenant milestone

Missing prerequisites are currently: the intended disposable tenant ID/domain, five real lab group object IDs, the actual emergency-access UPNs, any existing lab-owned user object IDs, admin consent for the two read scopes, and an operator account able to read those objects. No credentials belong in these files.

1. Establish the disposable tenant and confirm the domain used by synthetic UPNs is verified in it.
2. Create the five assigned-membership security groups from `organisation.json`. Do not make them role-assignable or dynamic.
3. Copy `config/organisation.json` to ignored `config/organisation.local.json`, and `config/employees.csv` to ignored `config/employees.local.csv`.
4. Replace tenant/domain/group placeholders and update the local CSV UPN domain. Replace protected emergency UPNs with the tenant's real protected identities. Set `managedUserObjectIds` to exact existing lab-owned IDs; use `[]` when there are none. Keep `allowMutation` false.
5. Install the Graph authentication module and connect interactively with read scopes only:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Connect-MgGraph -TenantId '<tenant-guid>' -Scopes @(
  'User.Read.All',
  'GroupMember.ReadBasic.All'
)
Get-MgContext
```

6. Export an exact-UPN, read-only snapshot and generate a local plan:

```powershell
./scripts/Export-LabGraphState.ps1 -EmployeePath ./config/employees.local.csv
./scripts/New-LabPlan.ps1 -EmployeePath ./config/employees.local.csv -ConfigurationPath ./config/organisation.local.json -CurrentStatePath ./config/current-state.local.json
```

7. Inspect the snapshot source/tenant, every object ID, all planned removals and every dependency. Stop here for the first read-only milestone. A permission, authentication, throttle, network or service failure must produce no new snapshot.

## Later write-enabled validation

After independent plan review, reconnect and consent only to the write permissions mapped in `permissions.md`. The combined workflow retains `User.ReadWrite.All` because manager assignment requires it; `User.ReadUpdate.All` is the narrower permission for profile updates considered alone. Only then set `allowMutation` true and invoke:

```powershell
Connect-MgGraph -TenantId '<tenant-guid>' -Scopes @(
  'User.Read.All',
  'User.Create',
  'User.ReadWrite.All',
  'User.EnableDisableAccount.All',
  'User.RevokeSessions.All',
  'GroupMember.ReadBasic.All',
  'GroupMember.ReadWrite.All'
)
./scripts/Apply-LabPlan.ps1 -PlanPath ./evidence/runs/latest-plan.json -ConfirmTenantMutation
```

Export a fresh snapshot, re-plan, investigate any remaining differences, then capture redacted evidence. Record created object IDs in `managedUserObjectIds` before a later run can manage them. Restore `allowMutation` false.

Do not reuse checked-in placeholder IDs, store access tokens/client secrets, or claim local sample output as tenant evidence.
