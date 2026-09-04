# Enterprise Identity Governance Lab

A small, plan-first Microsoft Entra identity administration lab for demonstrating joiner, mover and leaver (JML) controls, group-based access, least privilege, Privileged Identity Management (PIM), access reviews and defensible automation decisions.

Status: **local v0.2 implemented and tested; Graph mutation, PIM and access reviews are prepared but not tenant-tested.** No tenant was changed during either local implementation pass. Every checked-in identity, object ID, state snapshot and evidence sample is synthetic.

## What the demonstration shows

- A fictional organisation, Northstar Analytics, with six employees, reporting lines, three departments and an explicit access matrix.
- Deterministic reconciliation: desired HR-style CSV input + observed state -> a schema-2 change plan whose versioned checksum covers tenant, mode, operations and dependencies.
- Joiners receive a cloud identity and only baseline, department and manager groups.
- Movers lose obsolete lab-managed access before new access is granted.
- Leavers are disabled, have sessions revoked, and lose only access this lab owns; identities are retained for audit/recovery.
- Emergency-access and non-lab accounts fail closed. Conditional Access remains owned by the separate Zero Trust lab.
- Graph operations are behind tenant, scope, confirmation and plan-integrity gates.

## Architecture

```text
employees.csv + organisation.json + observed state
                    |
                    v
          pure PowerShell planner
                    |
          preview JSON (default)
                    |
       explicit gated apply (future tenant)
                    |
            Microsoft Graph v1.0
```

The core planner in `src/` has no cloud dependency. `scripts/` contains entry points; `config/` contains synthetic desired/observed data; `docs/` explains controls and portal exercises; `evidence/` separates examples from future tenant evidence; and `learning/` maps the work to SC-300.

## Quick start

Windows PowerShell 5.1 or PowerShell 7 can run the local workflow:

```powershell
./scripts/Invoke-Tests.ps1
./scripts/New-LabPlan.ps1
./scripts/Test-LabState.ps1 -CurrentStatePath ./config/converged-state.example.json
```

The preview proposes 17 operations: two joiners, one department mover and one leaver. The verification command returns compliant for the converged synthetic state. Generated runs go to ignored `evidence/runs/`; they are not real evidence.

The regression suite currently contains 32 tests. Graph export tests use mocked response/error objects, including pagination; they do not claim real tenant compatibility.

Do not run the apply entry point until the tenant prerequisites and safety checklist in [setup](docs/setup.md) are complete. The checked-in configuration has `allowMutation: false`, placeholder IDs and cannot pass the apply gates.

## Guided tour

1. [Scenarios and demo narrative](docs/scenarios.md)
2. [Access matrix](docs/access-matrix.md)
3. [Security and design decisions](docs/design-decisions.md)
4. [Graph permissions and prerequisites](docs/permissions.md)
5. [Lifecycle runbook](docs/runbooks/lifecycle.md)
6. [PIM runbook](docs/runbooks/pim-activation.md)
7. [Access review runbook](docs/runbooks/access-review.md)
8. [Evidence index](evidence/README.md) and [completion checklist](docs/completion-checklist.md)
9. [SC-300 mapping](learning/sc-300-mapping.md)

## Ownership boundary

This repository owns ordinary lab users, its prefixed security groups and their direct memberships. It exports a non-secret example integration manifest at `config/zero-trust-integration-manifest.example.json`. The Zero Trust Identity & Conditional Access Lab owns Conditional Access and emergency-access exclusions. This repository neither creates nor changes Conditional Access policies.

## Safety summary

Planning is always local and read-only. Applying requires a separately created ignored config, `allowMutation: true`, an explicit `-ConfirmTenantMutation`, a matching Graph tenant context, an intact plan hash, UPN prefix/domain checks, a protected-UPN denylist and a managed-group-ID allowlist. Cleanup deprovisions; it does not delete identities or groups.
