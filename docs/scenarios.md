# Scenarios and interview demonstration

Northstar Analytics is a fictional cloud-only organisation. The CSV is the simplified authoritative source; Microsoft Entra is the target directory. Direct security-group membership represents ordinary access. It intentionally does not model payroll, licence assignment, dynamic groups or Conditional Access.

## Scenario 1: joiner

Aisha Khan (Finance Manager) and Ethan Jones (Financial Accountant) do not exist in the starting state. The plan creates their identities with force-change-at-next-sign-in passwords generated only during apply, assigns the correct baseline/department groups, sets their managers and adds Aisha to the manager group.

Acceptance criteria:

- Preview contains `CreateUser` before dependent group/manager operations.
- A failed create causes dependent operations for that person to be skipped.
- No password or credential appears in source, plan or result evidence.
- A second plan against the converged state contains no joiner changes.

## Scenario 2: mover

Liam Patel moves from Finance to Engineering and changes manager from E005 to E004. The plan removes `EIGL-Finance`, updates attributes, adds `EIGL-Engineering`, and changes the manager. `external-project-x` is retained because this lab does not own it.

Acceptance criteria:

- Obsolete managed access is removed before replacement access is added.
- Unmanaged memberships are untouched.
- No Microsoft Entra directory role or Azure RBAC role is assigned by the lifecycle engine.

## Scenario 3: leaver

Sofia Rossi is marked `Leaver`. The plan first blocks sign-in, then requests session revocation, then removes all configured lab-managed memberships. It deliberately retains the directory object.

Session revocation is not instantaneous logout. Microsoft documents a possible delay of a few minutes. It invalidates refresh tokens and browser session cookies, but already-issued access tokens can remain usable until they expire; external-user sessions are controlled by the home tenant. Workloads can also have their own sessions. For that reason, disabling sign-in is the primary containment action and revocation is complementary. See [Microsoft Graph revokeSignInSessions](https://learn.microsoft.com/en-us/graph/api/user-revokesigninsessions?view=graph-rest-1.0).

Acceptance criteria:

- Disable precedes revocation and group removal.
- Only allowlisted group memberships are removed.
- Re-running a revocation is safe; the synthetic convergence marker prevents repeated preview noise, while a live snapshot conservatively cannot prove revocation completion.
- Deletion, mailbox handling, device actions and data retention remain explicit out-of-scope follow-on processes.

## Five-minute demonstration

1. Show `employees.csv`, the access matrix, and the starting snapshot.
2. Run `./scripts/New-LabPlan.ps1` and explain the 17-operation summary.
3. Filter the JSON for E002 and show remove-before-add plus preservation of external access.
4. Filter for E003 and explain disable versus token/session revocation.
5. Run `./scripts/Invoke-Tests.ps1`; highlight fail-closed validation and partial failure behavior.
6. Show the apply gates, PIM/access-review acceptance criteria, and evidence index; state clearly which artifacts are synthetic.
