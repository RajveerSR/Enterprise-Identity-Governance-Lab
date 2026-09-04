# Evidence index

Nothing checked in here is real tenant evidence.

| Artifact | Classification | What it proves |
|---|---|---|
| `plan-summary.example.json` | Synthetic local example | Expected operation counts and explicit preview label |
| `test-results.example.txt` | Synthetic local example | Offline safety/reconciliation tests passed on 4 Sep 2026 |
| `runs/` | Generated, git-ignored | Local plans and future redacted execution records |

Future tenant evidence should use filenames such as `tenant-01-pim-settings.redacted.png` and include capture time, tenant purpose, test case, expected/actual result and redaction note. Capture Entra audit/PIM/access-review records, not just portal success banners. Never commit tokens, credentials, temporary passwords, full tenant IDs, production UPNs or raw sensitive exports.

The completion checklist in `docs/completion-checklist.md` connects every capability to expected evidence.
