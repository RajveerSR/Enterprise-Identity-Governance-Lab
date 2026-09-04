# Setup

## Local-only workflow

No modules or tenant are required:

```powershell
./scripts/Invoke-Tests.ps1
./scripts/New-LabPlan.ps1
```

Inspect `evidence/runs/latest-plan.json`. It is ignored and labelled preview-only.

## Prepare a disposable tenant (future step)

1. Create the five assigned-membership security groups from `organisation.json`. Do not make them role-assignable or dynamic.
2. Copy `config/organisation.json` to ignored `config/organisation.local.json`.
3. Replace tenant/domain/group placeholders. Replace `managedUserObjectIds` with the exact IDs of existing lab-owned users (empty is safe for the first joiner-only plan). Keep `allowMutation` false. After creating a joiner, record its returned object ID before a later reconciliation can manage it.
4. Install the Graph authentication module and connect interactively:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Connect-MgGraph -TenantId '<tenant-guid>' -Scopes @(
  'User.Read.All',
  'User.Create',
  'User.ReadWrite.All',
  'User.EnableDisableAccount.All',
  'User.RevokeSessions.All',
  'GroupMember.ReadBasic.All',
  'GroupMember.ReadWrite.All'
)
Get-MgContext
```

5. Export an exact-UPN, read-only snapshot and review it:

```powershell
./scripts/Export-LabGraphState.ps1
./scripts/New-LabPlan.ps1 -ConfigurationPath ./config/organisation.local.json -CurrentStatePath ./config/current-state.local.json
```

6. Have a second person review the plan and scope. Only then set `allowMutation` true and invoke:

```powershell
./scripts/Apply-LabPlan.ps1 -PlanPath ./evidence/runs/latest-plan.json -ConfirmTenantMutation
```

7. Export a fresh snapshot, re-plan, investigate any remaining differences, then capture redacted evidence. Restore `allowMutation` false.

Do not reuse checked-in placeholder IDs, store access tokens/client secrets, or claim local sample output as tenant evidence.
