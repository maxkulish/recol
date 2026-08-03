# R0-02 - Delete the heavy governance machinery

Type: **AFK** | Blocked by: R0-00, R0-01 | Blocks: R0-05
Phase: 0 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 0)

## Goal

The governance layer built for upstream's multi-contributor review process is
gone, and no workflow, script, or agent instruction references a removed file.

## Context

These deletions are mutually referential and must land together: `ci.yml`
invokes the scripts, the `test_*.py` files import from `checks/`, and the root
YAML configures SpecRail. Splitting them leaves a commit where CI calls a
missing file.

Both deleted workflows use `pull_request_target` with `issues: write`, which on
a public repository is an attack surface as well as dead process.

`check_pr_preflight.py` is **retained** - `AGENTS.md:89` mandates it, and R0-01
already narrowed it.

Almost the entire diff is removals, so a green test suite proves it was inert.

## Scope

- [ ] Delete `.github/workflows/closure-audit.yml`, `sensitive-governance.yml`
- [ ] Delete from `scripts/ci/`: `run_sensitive_implement_gate.py`,
      `check_pr_tier.py`, `check_spec_lifecycle.py`, `closure_follow_up.py`,
      `extract_nonclosing_issue.py`, `specrail_sync_lock.py`,
      `test_specrail_gate_wiring.py`, `test_closure_follow_up.py`,
      `test_sensitive_governance_workflow.py`,
      `test_run_sensitive_implement_gate.py`, `test_extract_nonclosing_issue.py`,
      `test_schema_contract.py`
- [ ] Delete `checks/`, `.specrail/`, `scripts/sync-specrail-checks.sh`
- [ ] Delete root `labels.yaml`, `states.yaml`, `workflow.yaml`,
      `skills-lock.json`
- [ ] Delete `.github/ISSUE_TEMPLATE/epic.yml`, `spec.yml`, `implementation.yml`
- [ ] Strip every `ci.yml` step invoking a deleted file, including the
      hardcoded GH813 replay block
- [ ] Update `AGENTS.md` and `.github/pull_request_template.md` in this same
      commit so no instruction points at a removed executable

## Acceptance criteria

- [ ] `ls checks .specrail labels.yaml states.yaml workflow.yaml skills-lock.json` fails for every path
- [ ] `rg -n "specrail|SpecRail|check_pr_tier|closure_follow_up|sensitive_implement|test_schema_contract|spec_lifecycle" .github/ scripts/ AGENTS.md` returns nothing
- [ ] `rg -n "GH813|gh813" .github/` returns nothing
- [ ] `python3 scripts/ci/check_pr_preflight.py --base origin/main --pr-body-file /tmp/pr-body.md` exits 0
- [ ] `cargo test --workspace` exits 0
- [ ] CI passes on the pull request
