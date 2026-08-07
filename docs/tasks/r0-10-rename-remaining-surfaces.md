# R0-10 - Rename the remaining surfaces and gate the audit in CI

Type: **AFK** | Blocked by: R0-09 | Blocks: R0-12, R0-14, R0-16
Phase: 2 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 2)

## Goal

Every surface the project ships or executes carries the new name, the audit
passes, and CI enforces it from now on.

## Context

These surfaces do not affect the build, which is why they are separate from
R0-09, but three of them were wrongly frozen in an earlier draft and would have
produced two contradictory product identities:

- **`site/`** is the public installation and marketing surface, not historical
  evidence. `check_public_surface.py:44` covers it by name in `SITE_PAGES`.
- **`eval/local/run_local_eval.py` and `eval/locomo/run_locomo.py`** are
  executable. They invoke the binary and read `~/.remem/remem.db` and
  `REMEM_API_TOKEN`. Freezing them breaks them.
- **`CHANGELOG.md`** is version-synchronized, already handled in R0-09.

Frozen, and they stay frozen: `src/migrations/`, `specs/`, `eval/`'s artifacts
(`golden.json`, the claims registry, locomo fixtures, `eval/public/reports/`),
and the audits and analyses under `docs/`. Their condition IDs are referenced by
recorded results.

`check_public_surface.py` and `check_public_claims.py` are **retargeted**, not
deleted. They are what would have caught the frozen-`site/` mistake.

Root `schemas/` was dropped from Scope during R0-02: all 14 files were SpecRail
governance artifacts and went with the rest of that machinery. The eval schemas
the Rust code actually loads live under `eval/public/schemas/` and were never
in this task's list.

## Scope

- [ ] `site/`, `eval/local/run_local_eval.py`, `eval/locomo/run_locomo.py`
- [ ] `.agents/skills/remem-first-run-smoke/` and
      `.agents/skills/remem-plugin-version-sync/`, directories included
- [ ] `assets/`, `prompts/`, the tracked `.remem/` directory
- [ ] Current architecture, plugin, and release documents under `docs/`;
      historical audits untouched
- [ ] Retarget `check_public_surface.py` and `check_public_claims.py` to the new
      identity and the two surviving channels
- [ ] Add `rename_audit.py` as a step in the `rust` job

## Acceptance criteria

- [ ] `python3 scripts/ci/rename_audit.py` exits 0
- [ ] The same run confirms all four allowlisted literals still PRESENT
- [ ] `ls .agents/skills/` shows `recol-first-run-smoke` and `recol-plugin-version-sync`; no `remem-*` directory remains anywhere: `fd -H -t d -t f 'remem'` returns nothing
- [ ] `python3 scripts/ci/check_public_surface.py` exits 0
- [ ] `python3 scripts/ci/check_public_claims.py` exits 0
- [ ] `rg -l "remem" site/ eval/local/run_local_eval.py eval/locomo/run_locomo.py` returns nothing
- [ ] `rg -c "remem" eval/golden.json` still returns a non-zero count, proving artifacts were not touched
- [ ] `cargo test --locked --workspace` exits 0 and CI passes with the audit step present
