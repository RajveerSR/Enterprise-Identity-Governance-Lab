# PIM activation scenario

Scenario: Noah Williams needs occasional **User Administrator** access to support lab joiners. Make him eligible rather than permanently active, require MFA and justification, limit activation to one hour, and require approval by Maya Chen. This is a Microsoft Entra directory role—not Azure resource RBAC and not ordinary group access.

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

Status: documented only; requires a licensed tenant and has not been configured or tested.
