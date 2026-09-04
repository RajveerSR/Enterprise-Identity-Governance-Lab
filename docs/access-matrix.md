# Access matrix

These are direct, assigned-membership security groups. Application/resource access would be assigned to groups, not individuals. The matrix is encoded in `config/organisation.json`; this document is the human-readable control definition.

| Population | Baseline group | Department group | Additional group | Access intent |
|---|---|---|---|---|
| All active employees | EIGL-All-Employees | One of the groups below | None | Common low-risk resources |
| Engineering | EIGL-All-Employees | EIGL-Engineering | None | Engineering application/resource access |
| Finance | EIGL-All-Employees | EIGL-Finance | None | Finance application/resource access |
| Operations | EIGL-All-Employees | EIGL-Operations | None | Operations application/resource access |
| People managers | As above | As above | EIGL-People-Managers | Manager-only application features |
| Leavers | None | None | None | No managed ordinary access |

Least privilege is expressed as a closed mapping: an unknown department is an error, not a baseline-only fallback. A mover's old department group is removed. Memberships not in the configured managed-group allowlist are preserved because another owner may govern them.

## Three distinct authorization planes

| Plane | Example | Scope | Managed by the JML engine? |
|---|---|---|---|
| Group/application access | EIGL-Finance membership grants a finance app role | Group or enterprise app | Yes, only named lab groups |
| Microsoft Entra directory role | User Administrator can manage users in the directory | Tenant/directory | No; the PIM portal scenario makes it eligible |
| Azure resource role (Azure RBAC) | Reader on one resource group | Management group/subscription/resource group/resource | No; documented to show the boundary |

An Entra role authorizes directory administration; it does not grant access to Azure resources. An Azure RBAC role authorizes Azure Resource Manager resources; it does not grant Entra directory administration. Both can be governed by PIM, but they have different role systems, scopes and APIs.
