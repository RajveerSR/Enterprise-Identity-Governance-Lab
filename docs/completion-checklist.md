# Capability-to-evidence checklist

Evidence labels: **example** means synthetic/local; **tenant** must be captured from a real disposable tenant and must never be fabricated.

| Capability | Acceptance evidence | Current state |
|---|---|---|
| Organisation and access matrix | Config + documented matrix | Complete (example) |
| Joiner calculation | Plan shows two creates and dependent group/manager changes | Complete (example) |
| Mover least privilege | E002 loses Finance before gaining Engineering; external group untouched | Complete (example + automated test) |
| Leaver containment | Disable, revoke, managed removal order; token limitation explained | Complete (example + automated test) |
| Preview/apply separation | Default preview and gated apply script | Complete locally and verified in the 4 September tenant run |
| Idempotent convergence | Converged snapshot produces zero operations | Complete (automated test) |
| Input/scope safety | Duplicate, unknown department, out-of-scope and emergency-account tests | Complete (automated tests) |
| Plan integrity | Schema/version, tenant, mode, operations and dependencies survive JSON and detect change | Complete (local tests; checksum is not approval) |
| Partial failure | Mover replacement skips after failed removal; leaver containment continues but fails overall | Complete (mocked tests) |
| Graph integration | Exact endpoints/scopes, paginated read snapshot and write adapter | Successful live export/apply/readback verified; exporter failure cases remain mocked |
| PIM activation | Settings, eligibility, approval, activation and expiry audit | Live settings, eligibility, approval request and one-hour active window verified; post-expiry state not captured |
| Access review | Configuration, decisions, applied removal and audit | Runbook complete; tenant/licence evidence pending |
| Entra role vs Azure RBAC | Comparison in access matrix and interview explanation | Complete (documentation) |
| Zero Trust coordination | Non-secret identifiers and protected emergency UPNs; CA owner stated | Complete (example manifest) |
| Cleanup | Reviewed deprovisioning plan and post-cleanup verification | Implemented locally; tenant execution pending |

## Live lifecycle milestone

See the [4 September tenant evidence](../evidence/tenant/2026-09-04/README.md): 17 successful operations, two joiners created with groups/managers, Liam moved from Finance to Engineering, and Sofia disabled with lab memberships removed. Session revocation was accepted and its server timestamp advanced; active application-session behaviour was not tested. The fresh plan has no persistent-state changes but repeats the revocation action, so zero-operation tenant convergence is not claimed. An unrelated external group was not seeded in this live run; preservation of that case remains covered by the local test.

Service-side audit records and a fresh six-user state comparison were captured on 5 September; see the [follow-up evidence](../evidence/tenant/2026-09-05/README.md). A supervised PIM activation was captured on 6 September; see the [PIM evidence](../evidence/tenant/2026-09-06/README.md). Post-expiry PIM state, review decisions and cleanup remain pending. Finance ownership is prepared, but no access review was created.
