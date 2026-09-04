# Design decisions and threat model

## Plan before apply

The planner is pure local reconciliation. Plan schema 2 uses a versioned, canonical SHA-256 payload covering the plan schema, integrity-payload version, mode, tenant ID, operation content and dependencies. Verification rejects unsupported versions, invalid dependency graphs and changes that do not survive that contract. Apply then independently checks the configured tenant and target allowlists. The checksum detects change; it is not a signature, authenticated approval or proof of who reviewed the plan.

## Fail closed on ambiguity

Duplicate employee IDs/UPNs, unknown departments, unknown managers and collisions with unmanaged/protected accounts stop the whole plan. Silently choosing an interpretation would turn poor identity data into authorization changes.

## Two independent scope signals

An existing account needs its exact object ID allowlisted, `labManaged: true`, and a UPN whose local part/domain match the configured lab namespace. `managedUserObjectIds` is mandatory and must be an array; an explicit empty array safely authorizes no existing accounts while still allowing a new identity under the other controls. The read-only exporter derives `labManaged` from that object-ID list rather than trusting a matching name. A protected-UPN denylist overrides every allow signal. Group writes also require an exact configured object ID. These controls reduce blast radius; production would use a durable ownership attribute, dedicated administrative unit, workload identity restrictions and change approval.

## Remove only owned access

The planner reconciles direct membership only for configured `labManaged` groups. It does not enumerate and remove every membership. Transitive/dynamic membership, app-specific sessions, licences, devices and Azure RBAC require separate owners and runbooks.

## Partial failure over automatic rollback

Microsoft Graph operations are independent and non-transactional. The executor records each result, continues independent work, and skips operations whose prerequisites failed. Replacement mover access depends on every obsolete managed-membership removal for that transition, so a failed removal cannot leave old and new department access together. Unrelated identities continue. It does not automatically restore access after a later error. The recovery action is to inspect results, refresh state and generate a new plan containing only outstanding work.

## Leavers are disabled, not deleted

Immediate deletion complicates legal hold, mailbox/data handoff, investigation and recovery. The lab demonstrates rapid containment followed by managed access removal. A separate retention-approved process can delete after the required period.

Disablement, session revocation and managed-access removals are deliberately independent containment attempts. By default, a failed disable does not prevent revocation/removal, and a failed revocation does not prevent access removal. Any failure makes the overall result `Failed` and preserves per-operation evidence. `-StopOnFailure` is available for an operator who explicitly needs immediate halt semantics.

## Explicit exclusions

No Conditional Access policy, dashboard, approval application, additional identity platform or production credential handling is included. PIM and access reviews are portal exercises because demonstrating their native controls is more useful than wrapping them in bespoke automation in v0.1.
