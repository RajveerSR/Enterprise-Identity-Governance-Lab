# Capability-to-evidence checklist

Evidence labels: **example** means synthetic/local; **tenant** must be captured from a real disposable tenant and must never be fabricated.

| Capability | Acceptance evidence | Current state |
|---|---|---|
| Organisation and access matrix | Config + documented matrix | Complete (example) |
| Joiner calculation | Plan shows two creates and dependent group/manager changes | Complete (example) |
| Mover least privilege | E002 loses Finance before gaining Engineering; external group untouched | Complete (example + automated test) |
| Leaver containment | Disable, revoke, managed removal order; token limitation explained | Complete (example + automated test) |
| Preview/apply separation | Default preview and gated apply script | Complete locally; tenant execution pending |
| Idempotent convergence | Converged snapshot produces zero operations | Complete (automated test) |
| Input/scope safety | Duplicate, unknown department, out-of-scope and emergency-account tests | Complete (automated tests) |
| Plan integrity | Schema/version, tenant, mode, operations and dependencies survive JSON and detect change | Complete (local tests; checksum is not approval) |
| Partial failure | Mover replacement skips after failed removal; leaver containment continues but fails overall | Complete (mocked tests) |
| Graph integration | Exact endpoints/scopes, paginated read snapshot and write adapter | Implemented; exporter errors mocked, tenant untested |
| PIM activation | Settings, eligibility, approval, activation and expiry audit | Runbook complete; tenant/licence evidence pending |
| Access review | Configuration, decisions, applied removal and audit | Runbook complete; tenant/licence evidence pending |
| Entra role vs Azure RBAC | Comparison in access matrix and interview explanation | Complete (documentation) |
| Zero Trust coordination | Non-secret identifiers and protected emergency UPNs; CA owner stated | Complete (example manifest) |
| Cleanup | Reviewed deprovisioning plan and post-cleanup verification | Implemented locally; tenant execution pending |
