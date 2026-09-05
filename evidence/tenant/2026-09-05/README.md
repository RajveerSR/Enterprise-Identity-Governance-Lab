# Follow-up live governance evidence — 5 September 2026

A fresh read of all six lab users, their managers and the five managed groups found **zero persistent-state differences** from the successful 4 September lifecycle run. This comparison does not infer session revocation history or test an existing application's session.

The original change-window directory audit returned **25 lab-target records from 27 total records**. All 25 selected records report success, including two user creations, six group additions, three removals, three manager assignments, account disablement and a refresh-token-validity timestamp update. One requested operation can produce several audit records; 25 records does not mean 25 planner operations.

| Artifact | What it establishes |
|---|---|
| [Current state](current-state.redacted.json) | The six-user lifecycle result persists; P2 assignments are separately observed |
| [Directory audit](directory-audit.redacted.json) | Service-side action, target and result evidence from the original execution window |
| [Finance owner](finance-owner.redacted.json) | Maya is the named owner; Aisha and Ethan remain the two members |
| [Source hashes](source-hashes.json) | Change-detection hashes of the private source exports |

Maya, the Operations Director, is outside the reviewed Finance membership and provides an accountable reviewer. Assigning group ownership grants group-management authority; it does not create an Entra administrator role. No access review, decisions, stale test membership or automatic removal was created in this pass.

PIM and access-review API reads currently return HTTP 403 in the existing CLI session. Their current settings are therefore **unknown**, rather than assumed absent. `scripts/Export-GovernanceReadiness.ps1` is ready for a delegated session with the documented read permissions. Interactive consent, Noah's activation/Maya's approval and the review decisions remain pending.

These files are derived from actual Graph responses and omit tenant/domain/object IDs, real operator details and raw audit property values. They are not portal screenshots. Genuine lifecycle portal screenshots remain a supervised final step; the original pre-change state remains the saved Graph export.
