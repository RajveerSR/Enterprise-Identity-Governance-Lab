# Supervised PIM evidence - 6 September 2026

This evidence records a supervised Microsoft Entra Privileged Identity Management exercise for the fictional lab identity Noah Williams. The exercise used the User Administrator directory role and a separate approver, Maya Chen.

## Observed sequence

| Artifact | What it establishes |
|---|---|
| [Settings before](pim-settings-before.png) | Activation was limited to eight hours, required Azure MFA and justification, and did not require approval |
| [Settings after](pim-settings-after.png) | Maximum activation was reduced to one hour and approval was enabled while MFA and justification remained required |
| [Eligible assignment](pim-noah-eligible.png) | Noah received a direct, directory-scoped eligible assignment from 6 to 13 September 2026 |
| [Activation request](pim-activation-pending.png) | Maya's approver queue displayed Noah's justified User Administrator activation request |
| [Active assignment](pim-noah-active.png) | Noah's direct User Administrator assignment became active from 16:13:24 to 17:13:23 local time |
| [Source hashes](source-hashes.json) | SHA-256 hashes for the five unaltered screenshots |

The active start and end times show a one-hour window. These screenshots do not prove the eventual expiry or a manual early deactivation, so neither outcome is claimed. No privileged write performed by Noah was captured. The portal showed one configured approver, but the settings screenshot did not expand the approver link to display Maya's name; Maya's separate approval-queue screenshot establishes that she received the request.

## Privacy and provenance

The screenshots were supplied by the portfolio owner and are preserved unaltered. They expose fictional lab display names, truncated lab principal names, the lab tenant label and the portfolio owner's display name. They contain no password, passkey, token, QR code, full object ID or authentication secret.
