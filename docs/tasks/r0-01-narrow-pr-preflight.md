# R0-01 - Narrow the PR preflight to surviving checks

Type: **AFK** | Blocked by: none | Blocks: R0-02
Phase: 0 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 0)

## Goal

`check_pr_preflight.py` runs green while invoking only the checks that survive
the governance trim, so R0-02 can delete the rest without breaking the preflight
that `AGENTS.md` tells every agent to run.

## Context

`scripts/ci/check_pr_preflight.py` holds a list of `(name, command)` tuples.
Three entries invoke scripts R0-02 deletes:

- line 102: `check_spec_lifecycle.py`
- line 112: `test_specrail_gate_wiring.py`
- line 116: `scripts/sync-specrail-checks.sh --verify`

Six entries invoke scripts that are retained, and must keep working:
`check_plugin_version_sync.py` (118), `check_public_surface.py` (119),
`check_public_claims.py` (120), `check_file_size.py` (121),
`check_release_workflows.py` (122), `check_version_bump.py` (134).

This task must land **before** R0-02. Reversing the order leaves a commit where
the mandated preflight invokes files that no longer exist.

`AGENTS.md:89` documents the invocation, including the `--fast` subset. Keep
both modes working.

## Scope

- [ ] Remove the three doomed entries from the check list
- [ ] `--fast` still selects a mechanical subset of the remaining checks
- [ ] No other behaviour changes

## Acceptance criteria

- [ ] `printf 'test\n' > /tmp/pr-body.md && python3 scripts/ci/check_pr_preflight.py --base origin/main --pr-body-file /tmp/pr-body.md` exits 0
- [ ] `python3 scripts/ci/check_pr_preflight.py --fast --base origin/main --pr-body-file /tmp/pr-body.md` exits 0
- [ ] `rg -n "spec_lifecycle|specrail|sync-specrail" scripts/ci/check_pr_preflight.py` returns nothing
- [ ] `rg -c "check_plugin_version_sync|check_public_surface|check_public_claims|check_file_size|check_release_workflows|check_version_bump" scripts/ci/check_pr_preflight.py` returns 6
- [ ] `cargo test --workspace` exits 0
