# Local verification — 5 September 2026

Executed in Windows PowerShell/Python on the local repository. These are actual local results; they do not establish unrun PIM or review behavior.

| Check | Result |
|---|---|
| `powershell.exe -NoProfile -File scripts/Invoke-Tests.ps1` | 32 lifecycle tests plus 4 readiness-export tests passed; 0 failed |
| Prepared readiness scripts parsed by the PowerShell parser | Passed |
| JSON parsing across tracked/unignored JSON artifacts | Passed |
| Local Markdown links and referenced images | All targets present |
| Private tenant/operator markers and JWT-shaped values in tracked/unignored text | None found by the bounded scan |
| `git diff --check` | Passed after preserving LF line endings |

The new mocked export cases cover wrong-tenant refusal before any Graph call, pagination, permission failure recorded as incomplete, and refusal to follow a pagination URL outside Graph. An initial test-harness scope error was corrected before these results; it was not a live tenant failure.

Live evidence is separate under `evidence/tenant/`: the original lifecycle execution, later state readback, directory audit and Finance-owner verification. New Graph read scopes still require the operator's participation.
