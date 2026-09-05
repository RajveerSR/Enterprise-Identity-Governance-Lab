# Live lifecycle evidence - 4 September 2026

**17 operations succeeded; 0 failed; 0 skipped.** A fresh Microsoft Graph export confirmed the resulting accounts, managed memberships and reporting lines. These observations come from a real isolated lab tenant with fictional employees.

Executed at 16:08 UTC using repository commit `77a29f73bddddd66363f4f7ad74fd7a418718cb3`, Windows PowerShell 5.1 and Microsoft.Graph.Authentication 2.39.0. The reviewed plan was checked against a fresh export before invoking the repository's existing gated apply entry point. Local configuration used the actual Liam Smith account instead of the example Liam Patel identity.

## Observed before and after

| Scenario | Before | Verified after |
|---|---|---|
| Mover: Liam (E002) | Finance; All-Employees + Finance; no manager | Platform Engineer, Engineering; All-Employees + Engineering; manager Noah (E004) |
| Leaver: Sofia (E003) | Enabled; All-Employees + Finance | Disabled; no direct memberships in the five managed lab groups; revocation request succeeded and server session-validity timestamp advanced |
| Joiner: Aisha (E005) | Absent | Enabled Finance Manager; All-Employees + Finance + People-Managers; manager Maya (E001) |
| Joiner: Ethan (E006) | Absent | Enabled Financial Accountant; All-Employees + Finance; manager Aisha (E005) |
| Baseline: Maya and Noah | Existing accounts with configured memberships/managers | Observed profile and managed membership state unchanged |

Liam's Finance removal completed before his Engineering addition. The execution journal records each operation separately; the subsequent export checks the resulting state.

- [Before/after observations](state-comparison.redacted.json)
- [Execution journal and session timestamp evidence](execution.redacted.json)
- [Private source file hashes](source-hashes.json)

Tenant identifiers, real administrator details, domain and user object IDs are omitted from the public files. Fictional lab names and employee IDs are retained. Raw source files remain local. No passwords or tokens are included.

## What this run does and does not establish

The live JML workflow is verified. PIM activation, access-review execution, cleanup, Conditional Access outcomes and application access tests are still separate work. No Conditional Access, Security Defaults or Azure resources were changed by this run.

The fresh planner found no remaining account, profile, group or manager changes. It still proposes one session revocation because its exporter does not infer historical revocation. The execution journal plus the advancing server timestamp provide evidence of this run's request; an actual user's open application session was not tested. Do not describe this result as a zero-operation live rerun or guaranteed immediate sign-out from every application.

This run reused an existing delegated Azure CLI token with broad directory permissions and an administrator session; it did not demonstrate a least-privilege service identity or obtain new consent. Scope restrictions in the lab code do not narrow the underlying token's permissions. Emergency-account recovery was deferred by the operator and was not tested.

Creating the two joiners did not assign P2 licences or register authentication methods. Temporary passwords were not retained; interactive testing needs a controlled password reset and sign-in setup. Licence reclamation for the leaver was not part of this plan.

## Screenshot capture checklist

No portal screenshots have been captured for this run yet. The pre-change evidence is the saved Graph export; do not recreate it as a supposedly original portal screenshot. Capture the current portal state and pair it with the records above.

In Entra, open **Users > All users**, select the named lab user, then use **Properties** and **Groups**. Portal labels may vary slightly.

| Suggested file | What to capture | What a reviewer learns |
|---|---|---|
| `01-liam-profile.redacted.png` | Liam's department, job title and manager | The mover's profile and reporting line changed |
| `02-liam-groups.redacted.png` | Liam's complete group list showing Engineering and All-Employees | Engineering membership is present; Finance membership is absent |
| `03-sofia-disabled.redacted.png` | Sofia's account-enabled/sign-in-blocked state | The leaver account is disabled |
| `04-sofia-groups.redacted.png` | Sofia's Groups page with the complete empty result | Her direct lab memberships were removed |
| `05-aisha-profile.redacted.png` | Aisha's profile, employee ID and manager Maya | First joiner and manager relationship exist |
| `06-ethan-profile.redacted.png` | Ethan's profile, employee ID and manager Aisha | Second joiner and dependent manager relationship exist |
| `07-directory-audit.redacted.png` | If available, Entra audit entries around 16:08 UTC for these lab users; show action, target, result and timestamp | Independent service-side history corroborates the changes |

Keep dates, actions, fictional target names and result labels visible. Crop or redact your real administrator email, tenant/domain identifiers and unrelated users; never capture credentials, QR codes or tokens. Record the actual capture time and describe each redaction. An unavailable or delayed audit event should be labelled as such, not replaced with a fabricated success screen.

The README should embed two or three of the clearest captured images and link to this full evidence pack. Add image links only after files exist. Session revocation is supported by the journal and server timestamp, not by a screenshot of the disabled-account switch alone.
