# Access review scenario

Scenario: the Finance group owner reviews `EIGL-Finance` membership monthly. Reviewers decide whether each user still needs access; no response results in removal. This validates continued need after JML automation rather than assuming source data is always sufficient.

## Licence and roles

Microsoft's current feature guidance lists Microsoft Entra ID P2 or Microsoft Entra ID Governance for this group/application review scenario; current licensing fundamentals say Access Reviews requires Entra ID Governance for covered member users while some capabilities can operate with P2. Confirm the exact tenant SKU/feature before the demo and license reviewed member users and reviewers as required. Sources: [manage access with access reviews](https://learn.microsoft.com/en-us/entra/id-governance/manage-user-access-with-access-reviews) and [licensing fundamentals](https://learn.microsoft.com/en-us/entra/id-governance/licensing-fundamentals).

## Portal runbook

1. Ensure `EIGL-Finance` has a named owner who is independent enough to review access.
2. Open **Identity governance > Access reviews > New access review > Teams + Groups**.
3. Select only `EIGL-Finance`, review **all users**, and choose the group owner as reviewer.
4. Configure monthly recurrence, a short lab duration, justification required, reminders enabled and auto-apply results enabled.
5. Set **If reviewers don't respond** to **Remove access**. Keep recommendations visible, but require the human reviewer to evaluate context.
6. Start the review. Approve Aisha/Ethan only when their Finance need is confirmed; deny a deliberately stale test membership.
7. End/apply the review and verify the denied member is removed. Export review decisions/history and the corresponding group/audit change.

## Acceptance criteria

- Review scope contains only the intended lab group and direct membership population.
- Named accountable reviewer, recurrence, deadline, reminders, justification and no-response behavior are visible.
- At least one retain and one remove decision are evidenced in the test scenario.
- Applied results match group membership and are traceable in review/audit history.
- The lifecycle planner is run afterward and remains consistent; an unauthorized manual membership is not reintroduced by the access matrix.

Status on 5 September: Maya (Operations Director) is the verified Finance group owner; Aisha and Ethan are its two members. All have P2 assignments. The existing CLI session cannot read access-review definitions (HTTP 403), so an existing review is not assumed absent.

For the first supervised run, use `config/access-review.example.json` as a template, resolve the exact group and Maya IDs, and choose the actual start date. Its initial pilot is one instance with manual apply, no email notifications and no automatic no-response removals. This deliberately leaves decisions and removal under supervision while interactive testing is pending; it does not demonstrate the monthly auto-apply settings above.

During the supervised window, deliberately add Liam to Finance as the stale membership, capture that starting state, then have Maya retain Aisha/Ethan and deny Liam with reasons. Apply the completed review, confirm Liam loses Finance while retaining Engineering, and verify JML does not reintroduce Finance. Do not create stale access or a recurring removal timer while the reviewer is absent.

After the supervised result is verified, separately demonstrate the monthly recurrence/no-response/auto-apply configuration if retaining that acceptance requirement. Review and application of real decisions are not automated approvals by the assistant.

`AccessReview.Read.All` supports the pending inventory; creation later requires `AccessReview.ReadWrite.All` and an appropriate directory role. See [Microsoft Graph review creation](https://learn.microsoft.com/en-us/graph/api/accessreviewset-post-definitions?view=graph-rest-1.0).
