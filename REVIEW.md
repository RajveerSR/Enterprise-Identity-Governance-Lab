# Claude Code review handoff

## Implementation summary

- Added a PowerShell 5.1-compatible module for validated, deterministic JML planning, plan hashing, execution orchestration, Microsoft Graph v1.0 writes and state comparison.
- Added synthetic organisation/employee/current/converged data and a non-secret Zero Trust integration manifest.
- Added default-preview planning, read-only Graph snapshot, explicitly gated apply, verification, cleanup-preview and test entry points.
- Added scope controls for exact managed user IDs, lab UPN prefix/domain, protected emergency UPNs and exact managed group IDs.
- Added current Microsoft permissions/licensing documentation, lifecycle/PIM/access-review runbooks, interview narrative, SC-300 mapping and evidence checklist.

## Tests run

Command on 4 September 2026:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Tests.ps1
```

Result: **12 passed, 0 failed**. Coverage includes JML output, duplicate IDs, unknown departments, namespace and UPN-collision checks, converged repeated planning, partial failure continuation, dependent-operation skipping, unmanaged account protection, emergency-access protection, tamper detection and serialized-plan integrity.

`scripts/New-LabPlan.ps1` also completed and generated 17 expected preview operations. No tenant command was run.

## Implemented / mocked / untested

- Implemented and locally tested: validation, access calculation, operation ordering, plan integrity, safety checks, convergence and executor failure semantics.
- Mocked in tests: Graph executor success/failure and created-user ID propagation.
- Implemented but untested against a tenant: Graph snapshot and all Graph mutations.
- Documented only: tenant group creation, PIM activation and access review portal scenarios.

## Known limitations

- JSON plan hashes are integrity checks, not signed approvals.
- State export reads only employees in the input and direct membership in configured groups; it does not model dynamic/transitive access, licences, app sessions, devices or Azure RBAC.
- A live Graph snapshot cannot prove prior session revocation, so it conservatively sets the marker false. Repeated revocation is safe but may remain in a fresh plan.
- No automatic retry/backoff or Graph batch support yet. Partial failures require state refresh and re-plan.
- Create-user temporary password handoff is intentionally not implemented; apply creates it in memory and does not log it.
- The Graph module's response shapes/error messages need tenant validation, especially 404 detection and pagination.
- No cryptographic approval, administrative unit enforcement, workload identity/federated credential or production secret flow is included.

## Unresolved decisions

- Select a disposable tenant and replace user/group/domain/tenant placeholders.
- Choose the exact durable ownership marker for deployed users (schema extension, administrative unit or both).
- Decide an approved temporary-password delivery method, or replace password onboarding with Temporary Access Pass in a later version.
- Confirm whether the available tenant SKU supports the selected access-review options under its current licensing terms.

## Specific review questions

1. Can any crafted or stale plan bypass the apply-time UPN/group allowlists?
2. Is operation dependency handling correct when one of several joiners fails?
3. Are PowerShell 5.1 JSON/collection edge cases handled consistently, including zero/one operation plans?
4. Do the documented delegated permissions remain least-privileged for the exact property set?
5. Should disabling a user and session revocation be a stop-on-failure boundary before membership removal?
6. Is the live state export's conservative session-revocation behavior explained clearly enough?
