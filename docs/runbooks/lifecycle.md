# Lifecycle runbook

## Before a change

1. Confirm the request is for ordinary lab identities, not emergency access, privileged administrators or Conditional Access.
2. Validate the authoritative CSV change and manager/department mapping.
3. Refresh observed state from Graph when working in a tenant.
4. Generate and review the preview. Check removals first, tenant ID, UPNs and group IDs.

## Apply

Use `Apply-LabPlan.ps1` only after setup approval. Preserve the result JSON. A nonzero exit indicates a failed or skipped operation. Do not edit and replay a stale plan: refresh state and re-plan.

## Verify

- Export a fresh state and run `Test-LabState.ps1`.
- Confirm account enabled/disabled status and direct managed-group memberships in Entra.
- For a leaver, record the audit events for disable, revoke request and membership removals. Do not state that every access token was instantly invalidated.
- For joiners, hand off the temporary password through an approved channel; this repository does not log or distribute it.

## Cleanup

Generate `New-LabCleanupPlan.ps1`, review it, and pass that plan through the same apply gates. Cleanup disables identities, revokes sessions and removes lab-managed memberships. It does not delete user/group objects or touch external memberships. Deletion requires a separate retention-approved decision.

## Partial failure

1. Stop if the failure suggests wrong tenant/scope or unexpected authorization.
2. Preserve the result record and Graph request/audit correlation data when available.
3. Do not manually mark the synthetic convergence flag.
4. Refresh state and generate a new plan; completed operations should disappear, while failed work remains.
