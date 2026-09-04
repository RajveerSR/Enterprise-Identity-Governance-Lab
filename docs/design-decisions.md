# Design decisions and threat model

## Plan before apply

The planner is pure local reconciliation. A saved plan has a SHA-256 content hash over its operations. Apply verifies the hash and tenant, then rechecks the target UPN namespace and group allowlist. The hash detects accidental change; it is not a signature and does not establish who approved a plan.

## Fail closed on ambiguity

Duplicate employee IDs/UPNs, unknown departments, unknown managers and collisions with unmanaged/protected accounts stop the whole plan. Silently choosing an interpretation would turn poor identity data into authorization changes.

## Two independent scope signals

An existing account needs its exact object ID allowlisted, `labManaged: true`, and a UPN whose local part/domain match the configured lab namespace. The read-only exporter derives `labManaged` from that object-ID list rather than trusting a matching name. A protected-UPN denylist overrides every allow signal. Group writes also require an exact configured object ID. These controls reduce blast radius; production would use a durable ownership attribute, dedicated administrative unit, workload identity restrictions and change approval.

## Remove only owned access

The planner reconciles direct membership only for configured `labManaged` groups. It does not enumerate and remove every membership. Transitive/dynamic membership, app-specific sessions, licences, devices and Azure RBAC require separate owners and runbooks.

## Partial failure over automatic rollback

Microsoft Graph operations are independent and non-transactional. The executor records each result, continues independent work, and skips operations whose prerequisites failed. It does not automatically restore access after a later error. The recovery action is to inspect results, refresh state and generate a new plan.

## Leavers are disabled, not deleted

Immediate deletion complicates legal hold, mailbox/data handoff, investigation and recovery. The lab demonstrates rapid containment followed by managed access removal. A separate retention-approved process can delete after the required period.

## Explicit exclusions

No Conditional Access policy, dashboard, approval application, additional identity platform or production credential handling is included. PIM and access reviews are portal exercises because demonstrating their native controls is more useful than wrapping them in bespoke automation in v0.1.
