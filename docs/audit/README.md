# docs/audit - Codebase audit reports

Point-in-time audits of the codebase, each run against a specific commit and
crate version. They were previously loose at the top of `docs/`, where they
were hard to tell apart from the reference documentation that is kept current.

Nothing here is maintained after the fact. An audit describes what was true on
its date, and a later audit supersedes an earlier one rather than amending it.
The 2026-07-09 report links both of its predecessors and reconciles their open
findings against main as it stood then.

Read the newest first, and treat any finding as unverified until you have
checked it against current code. Several findings in these reports have since
been fixed, and the reports do not know that.

## Files

| Date | Scope |
|---|---|
| `audit-2026-07-09.md` | Full audit, 7 agents: contract, dataflow, security, architecture, config, tests, concurrency |
| `audit-2026-06-19.md` | Independent code-quality and security audit |
| `audit-2026-05-29.md` | Ledger baseline; remediation tracked in `docs/specs/SPEC-audit-remediation-2026-05-29.md` |

The `changed_files:` manifest at the end of the 2026-06-19 report lists that
file under its former path. That is deliberate: the manifest records where the
files were when the audit ran, and correcting it would misstate the record.
