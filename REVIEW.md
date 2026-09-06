# Independent review handoff

## Current state - 6 September 2026

The live JML run completed 17 operations successfully on 4 September using commit `77a29f7`. A later read of all six users, their managers and five managed groups found zero persistent-state differences. The original execution window yielded 25 successful lab-target directory audit records; these are not a one-to-one operation count.

Maya is the verified owner of EIGL-Finance, independently of its two Finance members. A fresh delegated read succeeded for role definitions, role eligibility, active assignments, role policies and access-review definitions. The tenant contained no eligibility and no access reviews at read time. A separate licence read confirmed 25 Entra ID P2 units with seven consumed; Noah and Maya were both observed with P2 assigned.

The supervised PIM exercise changed only the User Administrator activation controls: maximum duration was reduced from eight hours to one, MFA and justification remained required, and approval was enabled. Noah received a seven-day eligible assignment, his justified activation appeared in Maya's approval queue, and the resulting direct directory-scoped assignment was observed active for one hour. Post-expiry or manual-deactivation state was not captured. See the [6 September PIM evidence](evidence/tenant/2026-09-06/README.md).

## Local verification and boundaries

- 32 existing lifecycle/integrity/scope/dependency/export tests pass.
- Four new read-only governance export tests pass: tenant mismatch, complete pagination, permission failure and untrusted pagination refusal. These use mocked Graph calls.
- `Export-GovernanceReadiness.ps1` requires an existing delegated session in the exact expected tenant, performs GETs only and labels partial exports as incomplete before failing.
- `config/access-review.example.json` is a synthetic supervised pilot template: one instance, named reviewer, manual apply, no automatic no-response removal or email notifications. It is not a deployed review.
- The delegated readiness export marked itself incomplete because its consent set omitted the licence-read permission required by `/subscribedSkus`; every governance and PIM endpoint in that export succeeded. Licence state was confirmed separately and the partial export remains private.
- The PIM screenshots establish the policy change, eligibility, approval request and bounded active state. They do not establish expiry, deactivation or a privileged task performed by Noah.

Earlier implementation milestones remain in history: `8c01b5e` integrity/scope; `9d498c3` mover/leaver failure handling; `e4a72c2` structured Graph export. No history was rewritten and nothing was pushed remotely.

## Review focus

1. Correlate the [live lifecycle pack](evidence/tenant/2026-09-04/README.md) with [follow-up state and directory audit](evidence/tenant/2026-09-05/README.md).
2. Preserve the distinction between persistent state convergence and the repeated revocation action in a fresh plan.
3. Check permission-error handling: an unreadable PIM/review endpoint must not be reported as empty or configured.
4. Before PIM setup, read the current role policy and assignments; changes to a role's policy affect its other assignees too. Prepare eligibility, not a permanent active role.
5. Before access-review execution, prepare an explicit stale membership during the supervised window, collect decisions and verify applied removal without reintroducing it through JML.

The live CLI session used broad delegated directory privileges. Code scope checks do not narrow that token, and this project has not demonstrated a least-privilege service identity. No live cleanup or open-application-session invalidation test has been performed.
