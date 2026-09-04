# Microsoft Graph permissions and prerequisites

Checked against Microsoft Learn on 4 September 2026. Use delegated access for the initial interactive lab so the app consent **and** the operator's Entra role constrain changes. Admin consent is required for the privileged scopes below. Do not grant `Directory.ReadWrite.All` as a shortcut.

| Operation | Graph v1.0 endpoint | Least-privileged delegated permission used/needed | Notes |
|---|---|---|---|
| Read users | `GET /users/{id}` | `User.Read.All` | Exact configured UPNs are read, not a broad mutation target. |
| Create user | `POST /users` | `User.Create` | Current docs list `User.Create` for delegated and application access. |
| Update profile/manager | `PATCH /users/{id}`; `PUT /users/{id}/manager/$ref` | `User.ReadWrite.All` | Manager assignment specifically requires `User.ReadWrite.All`. |
| Disable account | `PATCH /users/{id}` | `User.EnableDisableAccount.All` + `User.Read.All` | Least-privileged combination for `accountEnabled`; the operator also needs a supported directory role. |
| Revoke sessions | `POST /users/{id}/revokeSignInSessions` | `User.RevokeSessions.All` | May take several minutes; does not revoke external users' home-tenant sessions. |
| Read groups/membership | `GET /groups/{id}/members` | `GroupMember.ReadBasic.All` | Hidden membership would also need `Member.Read.Hidden`; this lab does not use it. |
| Add/remove user membership | `POST .../members/$ref`; `DELETE .../members/{id}/$ref` | `GroupMember.ReadWrite.All` | Role-assignable groups additionally need `RoleManagement.ReadWrite.Directory`; this lab forbids them. Always retain `/$ref` when removing. |

Microsoft sources: [create user](https://learn.microsoft.com/en-us/graph/api/user-post-users?view=graph-rest-1.0), [update user/accountEnabled](https://learn.microsoft.com/en-us/graph/api/user-update?view=graph-rest-1.0), [assign manager](https://learn.microsoft.com/en-us/graph/api/user-post-manager?view=graph-rest-1.0), [revoke sessions](https://learn.microsoft.com/en-us/graph/api/user-revokesigninsessions?view=graph-rest-1.0), [list group members](https://learn.microsoft.com/en-us/graph/api/group-list-members?view=graph-rest-1.0), [add member](https://learn.microsoft.com/en-us/graph/api/group-post-members?view=graph-rest-1.0), and [remove member](https://learn.microsoft.com/en-us/graph/api/group-delete-members?view=graph-rest-1.0).

## Entra directory role prerequisites

Delegated permissions do not replace the signed-in user's directory authorization. For ordinary non-role-assignable groups, group membership APIs support roles including Groups Administrator and User Administrator; group owners can also update their groups. User Administrator is the practical single demo role for non-admin lab users, but apply the narrowest role(s) that fit the exact exercise. Sensitive changes to administrator accounts require higher roles; this lab refuses those accounts.

## Local and tenant prerequisites

- Windows PowerShell 5.1 or PowerShell 7.
- `Microsoft.Graph.Authentication` for `Connect-MgGraph`, `Get-MgContext` and `Invoke-MgGraphRequest`.
- A disposable Microsoft Entra test tenant and a verified domain.
- Five assigned-membership, non-role-assignable security groups whose IDs replace the placeholders.
- A dedicated operator; do not use an emergency-access identity.
- Delegated admin consent for only the scopes above.
- For the manager snapshot endpoint, use delegated authentication; the current API table does not support application permission for `GET /users/{id}/manager`.

The checked-in configuration cannot mutate a tenant. See [setup](setup.md) for the opt-in flow.
