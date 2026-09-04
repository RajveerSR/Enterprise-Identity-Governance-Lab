# SC-300 learning map

| SC-300 theme | Lab artifact | Explain it aloud |
|---|---|---|
| Implement and manage user identities | JML planner, Graph adapter, lifecycle runbook | Authoritative input is validated before scoped reconciliation. |
| Implement and manage groups | Access matrix and membership operations | Groups decouple people from resource assignment and make mover removal explicit. |
| Manage access with Entra roles | PIM activation scenario | Eligible, time-bound activation reduces standing privilege. |
| Plan identity governance | Access-review scenario and evidence checklist | Provisioning answers initial need; reviews recertify continued need. |
| Monitor identity | Verification, apply results and audit evidence plan | Desired state alone is not proof; observed state and audit records close the loop. |
| Secure identities | Emergency-account denylist and blast-radius controls | Break-glass accounts must remain independent of ordinary automation. |

## Practice scenarios

1. HR sends E002 twice with different departments. Answer: reject the complete batch; don't pick the last row, because the authorization intent is ambiguous.
2. A mover has an unmanaged project group. Answer: preserve it, notify that group's owner if review is needed, and remove only groups this controller owns.
3. A leaver's refresh tokens are revoked. Can you claim immediate total logout? Answer: no—disable first, explain access-token lifetime, propagation delay, workload sessions and external home-tenant limits.
4. A script has `GroupMember.ReadWrite.All`. Can its signed-in operator always change every group? Answer: no—delegated consent and the operator's directory role both matter; role-assignable groups impose stronger requirements.
5. User Administrator versus Azure `Owner`: Answer: the first is a Microsoft Entra directory role; the second is Azure RBAC over an ARM scope. Neither implies the other.
6. An apply fails halfway. Answer: don't blindly rollback access. Preserve results, refresh observed state, investigate authorization/scope and re-plan.

## Study prompts

- Why is an unknown department a hard failure rather than “no access”?
- When would dynamic groups be preferable, and how would ownership/reconciliation change?
- What evidence proves a PIM role expired rather than merely that activation was requested?
- Who should review Finance access, and what conflict of interest could a self-review create?
- What stronger production ownership marker would replace a JSON `labManaged` flag?
