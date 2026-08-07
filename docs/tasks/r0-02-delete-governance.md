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

`tools/install_codex_skills.py` was added to Scope during execution. It puts
`checks/` on `sys.path` and imports `specrail_lib` at module scope, so the
`checks/` deletion breaks it at import, and it validates `skills-lock.json`,
another path deleted here. The acceptance greps below search `.github/`,
`scripts/` and `AGENTS.md`, so nothing would have caught it. `skills/` follows
it: 11 SpecRail skill directories, inert markdown, orphaned once the AGENTS.md
SpecRail section is gone.

`AGENT_USAGE.md` was added on the same grounds. Every artifact it lists -
`workflow.yaml`, `states.yaml`, `labels.yaml`, `skills-lock.json`,
`skills/specrail-*` - is deleted here, and both commands it gives agents invoke
`checks/`. Nothing survived the deletions, so it is removed rather than
rewritten; its one durable rule, that agents must not approve, merge, or bypass
gates, moves into `AGENTS.md`.

Five further directories went the same way once the greps above were widened
past the criteria's search paths: `templates/` and `review/` tell agents to run
`checks/pr_gate.py`, `checks/github_pr_evidence.py` and
`checks/review_json_gate.py`; `integrations/threads.md` loads `workflow.yaml`,
`states.yaml`, `labels.yaml` and `skills/specrail-workflow`; root `schemas/` is
14 SpecRail artifact schemas; `artifacts/logs/gh871/` is one upstream SpecRail
run log.

`policies/` and `prompts/` are **retained**. `policies/` is two generic
documents with no SpecRail reference, and `prompts/` is compiled into the
binary through `include_str!`. Root `schemas/` is not the eval schema
directory: the files `src/eval/` loads are under `eval/public/schemas/` and are
untouched. R0-10 listed root `schemas/` as a rename target and has been
corrected.

`.specrail/` is named below but does not exist in the tree. Criterion 1 asserts
`ls` fails for it, which an absent path already satisfies.

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
- [ ] Delete `tools/install_codex_skills.py`, the sole file in `tools/`
- [ ] Delete `skills/`, all 11 `specrail-*` directories
- [ ] Delete `AGENT_USAGE.md`, keeping its human-gate rule in `AGENTS.md`
- [ ] Delete `schemas/`, `templates/`, `review/`, `integrations/`, `artifacts/`
- [ ] Strip every `ci.yml` step invoking a deleted file, including the
      hardcoded GH813 replay block
- [ ] Update `AGENTS.md`, `.github/pull_request_template.md`, `CONTRIBUTING.md`
      and `.pr_agent.toml` in this same commit so no instruction points at a
      removed executable

## Acceptance criteria

- [ ] Every deleted path is absent, checked **one at a time**. A single
      multi-operand `ls` cannot verify this: `ls present absent` exits 1, the
      same code as `ls absent absent`, so one surviving path is
      indistinguishable from none. The loop below names any survivor and prints
      nothing when the sweep is complete:

      ```sh
      for p in checks .specrail labels.yaml states.yaml workflow.yaml \
               skills-lock.json tools skills AGENT_USAGE.md schemas \
               templates review integrations artifacts; do
        [ -e "$p" ] && echo "STILL PRESENT: $p"
      done
      ```

- [ ] The sweep stopped at the governance boundary: `policies/` and `prompts/`
      both still exist and `cargo check` passes. `prompts/` is compiled in via
      `include_str!`, so its loss fails the build rather than any grep.

      ```sh
      for p in policies prompts; do
        [ -e "$p" ] || echo "WRONGLY DELETED: $p"
      done
      cargo check
      ```
- [ ] `rg -n "specrail|SpecRail|check_pr_tier|closure_follow_up|sensitive_implement|test_schema_contract|spec_lifecycle" .github/ scripts/ AGENTS.md` returns nothing
- [ ] The same search over the **whole active tree** returns nothing. Three
      paths are not enough: this criterion as originally written passed green
      while `tools/`, `AGENT_USAGE.md`, `CONTRIBUTING.md` and `.pr_agent.toml`
      all still referenced deleted machinery. `docs/`, `specs/` and
      `CHANGELOG.md` are excluded because they are the historical record and
      must keep naming what was removed:

      ```
      rg -n --hidden -g '!.git/**' -g '!target/**' -g '!docs/**' \
        -g '!specs/**' -g '!CHANGELOG.md' -g '!.session/**' \
        "specrail|SpecRail|check_pr_tier|closure_follow_up|sensitive_implement|test_schema_contract|spec_lifecycle|enforcement_sensitive"
      ```
- [ ] `rg -n "GH813|gh813" .github/` returns nothing
- [ ] `python3 scripts/ci/check_pr_preflight.py --base origin/main --pr-body-file /tmp/pr-body.md` exits 0
- [ ] `cargo test --workspace` exits 0
- [ ] CI passes on the pull request
