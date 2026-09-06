# PIM activation scenario

Scenario: Noah Williams needs occasional **User Administrator** access to support lab joiners. Make him eligible rather than permanently active, require MFA and justification, limit activation to one hour, and require approval by Maya Chen. This is a Microsoft Entra directory role. Azure resource RBAC and ordinary group access are separate concepts.

## Licence and roles

Microsoft currently requires Microsoft Entra ID P2 or Microsoft Entra ID Governance for PIM and its settings. Licence eligible/time-bound assignees and approvers as applicable. A Privileged Role Administrator manages Entra role eligibility/settings. Sources: [PIM getting started](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-getting-started) and [licensing fundamentals](https://learn.microsoft.com/en-us/entra/id-governance/licensing-fundamentals).

## Portal runbook

1. In Microsoft Entra admin center, open **Identity governance > Privileged Identity Management > Microsoft Entra roles**.
2. Open **Assignments**, add Noah as **Eligible** for **User Administrator**, with an explicit lab end date.
3. In role settings, require MFA on activation, justification and approval; select Maya as approver; set maximum duration to one hour. Do not create a permanent active assignment.
4. As Noah, open **My roles**, activate User Administrator, enter a ticket-style justification and request approval.
5. As Maya, validate the stated task and approve. Confirm Noah becomes active for no more than one hour.
6. Perform a harmless read/controlled lab task, then deactivate early. Export PIM audit/assignment evidence and redact tenant/user identifiers if publishing.

## Acceptance criteria

- Before activation Noah is eligible, not active, and cannot perform the privileged operation.
- Activation records MFA, justification, approver and bounded start/end time.
- Approval produces a temporary active assignment; expiry/deactivation removes it.
- Evidence includes licence edition, role settings, eligibility, request/approval and audit history.
- No emergency-access identity is made eligible or used as approver.

Status on 6 September: a fresh delegated read found no existing eligibility, one permanent Global Administrator assignment and the default User Administrator policy. The supervised exercise then changed the User Administrator activation maximum from eight hours to one, preserved MFA and justification, enabled approval, made Noah eligible for seven days and produced a one-hour active assignment after the request appeared in Maya's approval queue. See the [6 September evidence](../../evidence/tenant/2026-09-06/README.md). Expiry or manual deactivation was not captured.

Before making changes, run `scripts/Export-GovernanceReadiness.ps1` in an authenticated delegated Graph session. Use `RoleManagement.Read.Directory` and `RoleManagementPolicy.Read.Directory` for the role/eligibility/settings inventory. Resolve User Administrator from the service, inspect existing assignees and save the current rules. Role settings are shared by other assignees of that role; do not replace an unread policy or discard stronger existing controls.

Prepared target: Noah eligible for seven days, maximum one-hour activation, MFA, justification and Maya's approval. Start the eligibility window only when the supervised exercise is ready. Maya/Noah must complete their own sign-ins and MFA/approval steps. No permanent active assignment or automated self-approval is part of the exercise.

For later setup, Microsoft documents `RoleEligibilitySchedule.ReadWrite.Directory` for eligibility requests and `RoleManagementPolicy.ReadWrite.Directory` for rule updates. These write scopes are not requested by the prepared read-only script. Sources: [eligibility requests](https://learn.microsoft.com/en-us/graph/api/rbacapplication-post-roleeligibilityschedulerequests?view=graph-rest-1.0), [policy rules](https://learn.microsoft.com/en-us/graph/api/unifiedrolemanagementpolicyrule-update?view=graph-rest-1.0).
