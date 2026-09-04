# Claude Code review handoff

## Follow-up implementation summary

- Plan schema 2 now hashes a deterministic payload containing schema version, integrity-payload version, mode, tenant ID, operation content and dependencies. Unsupported versions, duplicate/missing/forward dependencies and metadata changes fail verification. Zero-, one- and multi-operation JSON round trips pass.
- `scope.managedUserObjectIds` is mandatory, non-null and array-typed. `[]` authorizes no existing users while allowing scoped joiners. Planner and apply-boundary checks share the same validation; emergency UPNs still override allow signals.
- Every mover replacement group addition depends on all obsolete managed-group removals for that employee. One failed removal skips replacement access, while other removals and unrelated users continue. Refresh/re-plan retains only outstanding work.
- Leaver containment is deliberately independent by default: disable, revoke and managed removals continue after another containment failure. Any failure/skipped action makes the overall result `Failed`; `partiallyCompleted` is explicit. `-StopOnFailure` is tested as an operator-selected alternative.
- Graph export logic moved into an injectable module function. Only structured HTTP 404 or recognized Graph not-found codes mean absence. Message-only errors and 401/403/429/503/connectivity failures remain visible and prevent snapshot output. Pagination and manager/user behavior are mocked locally.
- Permissions were rechecked on 4 September 2026 against official Microsoft Learn. Profile update (`User.ReadUpdate.All`) and manager assignment (`User.ReadWrite.All`) are separate; the combined write workflow retains `User.ReadWrite.All` because manager assignment requires it.

## Meaningful local commits

- `8c01b5e` — plan integrity and strict scope validation.
- `9d498c3` — mover dependency and leaver failure semantics.
- `e4a72c2` — structured read-only Graph export and permission/readiness documentation.
- A final evidence/handoff commit follows these and should contain only version/reporting artifacts.

No history was rewritten and nothing was pushed.

## Regression and verification results

Before fixes, the new regressions reproduced:

- 13 passed / 3 failed for tenant/mode integrity and missing allowlist.
- 21 passed / 6 failed after adding mover/leaver expectations.
- 29 passed / 3 failed before the structured exporter seams existed.

Final command:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Tests.ps1
```

Result: **32 passed, 0 failed**. This includes existing unmanaged-membership and joiner/manager dependency coverage plus the follow-up regressions.

Local planning still produces **17 preview operations** (2 create, 1 update, 1 disable, 1 revoke, 6 add membership, 3 remove membership, 3 set manager) using plan schema 2 / integrity payload 1. The converged snapshot verifies with zero differences. Cleanup remains an 18-operation preview. The checked-in apply configuration stops at `allowMutation: false`. No tenant command was run.

## Implemented, mocked and unverified

- Locally executed: validation, reconciliation, plan serialization/integrity, scope boundary, executor dependency/failure behavior, converged verification, planning and cleanup preview.
- Mocked: Graph user/manager 404s, pagination, created-user ID propagation, partial mutations, 401/403/429/503/connectivity failures.
- Implemented but tenant-unverified: actual `Invoke-MgGraphRequest` response/error shapes, Graph snapshot, user/group/manager mutations and result correlation.
- Documented only: tenant group creation, PIM activation and access review.

## Known limitations and unresolved decisions

- SHA-256 is change detection, not a signature, authenticated approval or provenance control.
- Real Graph exception shapes may differ from mocks; first tenant work must be read-only and must confirm 404/pagination behavior.
- State export covers exact input UPNs and direct configured-group memberships only, not transitive/dynamic access, licences, app sessions, devices or Azure RBAC.
- A live snapshot cannot prove prior session revocation, so repeated revocation can remain planned.
- No retry/backoff, batch support or automatic rollback. Recovery is refresh, inspect and re-plan.
- Establish the disposable tenant, verified domain, five group IDs, emergency UPNs, any existing managed-user IDs, read-scope consent and operator access.
- Choose a durable production ownership marker and a Temporary Access Pass or other approved onboarding handoff before production-style use.
- Confirm the available tenant licence supports the chosen PIM/access-review options.

## First read-only tenant milestone

Follow `docs/setup.md`: create ignored `organisation.local.json` and `employees.local.csv`, keep `allowMutation` false, fill real identifiers, connect with only `User.Read.All` and `GroupMember.ReadBasic.All`, export state, generate a plan and inspect every object/removal/dependency. Stop before apply. Any non-404 Graph failure must leave no new snapshot.

## Claude review checklist

- [ ] Recalculate/tamper schema-2 payload fields and confirm integrity fails as intended.
- [ ] Try missing, null, scalar and empty `managedUserObjectIds` at planner and apply boundaries.
- [ ] Trace E006's two create dependencies and an E002 multiple-removal failure.
- [ ] Verify leaver default continuation, overall failure and `-StopOnFailure` behavior.
- [ ] Inspect structured error extraction for likely Microsoft.Graph exception shapes and false-404 risk.
- [ ] Recheck the split profile/manager permissions and read-only consent set against current official docs.
- [ ] Confirm documentation does not present mocked output as tenant evidence.
