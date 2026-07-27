# R0-08 - Write the rename manifest and audit, red first

Type: **AFK** | Blocked by: none | Blocks: R0-09
Phase: 2 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 2)

## Goal

A script that can prove the rename is complete and that it did not destroy the
literals which must survive - written and proven to fail **before** any renaming
happens.

## Context

An earlier draft of the plan asserted `rg -i remem src/` must return nothing
after the rename. That assertion is impossible: `remem_static` and
`remem_version` are data-bound strings that appear throughout `src/` and must
not change.

The audit therefore does two things, and the second is the one that catches real
damage: it fails on unexpected occurrences, **and** it fails if an allowlisted
literal has gone missing.

Preserved-literal allowlist, all of which must still be present after R0-10:

| Literal | Frozen in | Also live in |
|---|---|---|
| `remem_static` | `v010_ai_usage_token_breakdown.sql:7` | `src/db/usage.rs:75`, `src/ai/pricing.rs:23`, `src/ai/tests.rs:128`, `src/db/query/stats/tests.rs` |
| `remem_static_backfill` | `v011_reprice_ai_usage_events.sql:88` | `src/migrate/tests.rs:367` |
| `remem_version` | `v063_procedure_exports.sql:14` | `src/memory/procedure/registry.rs:84,93`, `src/memory/procedure/export/render.rs:343` |
| `Copyright (c) 2026 majiayu000` | `LICENSE:3` | release archives |

`remem_version` is a live column, written by the procedure registry and emitted
as an export key. Renaming one side and not the other breaks the procedure
export silently.

Frozen paths, excluded from the scan: `src/migrations/`, `specs/`,
`eval/golden.json`, the claims registry, the locomo fixtures,
`eval/public/reports/`, and the audits and analyses under `docs/`.

## Scope

- [ ] A manifest of in-scope paths, frozen paths, and the literal allowlist,
      stored as data both the rename script and the audit read
- [ ] `scripts/ci/rename_audit.py` reporting unexpected occurrences and missing
      allowlisted literals as separate failure classes
- [ ] A `--self-test` mode proving the audit detects a removed literal

## Acceptance criteria

- [ ] On the current tree, `python3 scripts/ci/rename_audit.py` exits **non-zero** and reports more than 1,000 in-scope occurrences
- [ ] The same run reports all four allowlisted literals as PRESENT
- [ ] The same run reports zero findings under `src/migrations/`, `specs/`, and `eval/golden.json`
- [ ] `python3 scripts/ci/rename_audit.py --self-test` exits 0, and its output shows a fixture with a deleted allowlisted literal being detected as a failure
- [ ] `cargo test --workspace` exits 0 - this task adds no Rust
