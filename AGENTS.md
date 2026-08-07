# remem Agent Instructions

## Scope

This file applies to the whole repository unless a nested `AGENTS.md` overrides it.

remem 的目标是做最强的 Claude Code / Codex 记忆系统，不是最便宜的。所有设计决策优先判断：记忆质量是否提升。成本、延迟、依赖复杂度都排在记忆质量之后。

## Start Here

1. Run `git status --short` before changing files. This repo often has active staged and unstaged work.
2. Read `README.md` for user-facing behavior and `docs/ARCHITECTURE.md` for current runtime/data-flow context.
3. Read `docs/specs/README.md` before treating any old `docs/specs/*.md` file as pending work. Most historical specs have been implemented, superseded, or absorbed into the current architecture.
4. For Codex plugin/runtime work, also read `plugins/remem/README.md`, `plugins/remem/skills/remem/SKILL.md`, and the version-sync files listed below.
5. Use repo-local skills under `.agents/skills/` when a task matches one.
6. Search existing code and docs before creating new files. Similar-file creation without search is not acceptable.

## Core Rules

- Do not remove LLM extraction or automatic capture to save cost. Past zero-LLM direction weakened memory quality.
- Do not rely on agents voluntarily calling `save_memory`; automatic hook capture is the primary path, manual save is only a supplement.
- No silent degradation for missing or wrong memory/context. User-visible data loss must return an error or log at error level with enough detail to diagnose.
- Prefer current implementation truth over old spec text. When an old spec disagrees with code, verify with tests and update the spec index or spec status instead of reimplementing stale design.
- Keep changes scoped to the requested behavior. Avoid opportunistic refactors unless they are required for correctness.

## Spec Routing

Use specs as contracts only after checking their status in `docs/specs/README.md`.

Current implementation contracts live under `docs/specs/`; update those when a
change modifies the behavior they already govern. `specs/GH<issue-number>/` is
a historical packet directory inherited from upstream and is not a destination
for new work.

Task work is tracked in `docs/tasks/` and `project.md`, and run through
`/task:orchestrate`. A task file is its own spec, and its acceptance criteria
are the standard the change is judged against.

`scripts/gate.sh` does **not** run them. Their expected results are stated in
prose - "returns nothing", "fails for every path" - which is what makes them
good criteria and bad shell, so layer L1 reports `MANUAL` and the gate can exit
`0` with every criterion still unverified. A PASS means the compiler, the test
suite and the YAML parsed. Running the criteria and recording their output is
yours.

Agents may draft, implement, diagnose, and review. Agents must not give final
approval, merge, force-push, publish private security details, or bypass
review, security, or release gates.

| Change | Required path |
|---|---|
| Small bugfix with clear root cause | Implement directly, add or update a focused regression test |
| User-facing behavior change | Update `README.md` and add/update a current spec if behavior is ambiguous |
| Multi-module runtime, DB, hook, or plugin change | Write or update a current `docs/specs/<id>/PRODUCT.md` and `TECH.md` pair before implementation |
| Historical `SPEC-*.md` says "proposed" or "active" | Check `docs/specs/README.md` and current code first; many are historical implementation references |
| Old refactor-step specs | Treat `docs/specs/refactor-steps/` as completed historical split contracts unless current code proves drift |

Issues are disabled on this repository, so pull requests link no issue and the
`Refs` / `Closes` distinction that upstream enforced does not apply. The
machine check behind it is gone. `docs/specs/spec-lifecycle-governance/` is
retained as a historical contract, not as an active rule.

## High-Risk Areas

- Migrations and schema drift: inspect `src/migrate/`, `src/migrations/`, `src/db/`, and schema tests before changing DB behavior.
- Capture and extraction: inspect `src/db/capture.rs`, `src/db/extraction.rs`, `src/worker.rs`, `src/observation_extract.rs`, and `src/memory_candidate.rs`.
- Context injection: inspect `src/context/` and SessionStart/Stop hook behavior before changing output or gating.
- API and local app: inspect `src/api/`, `tests/api_public.rs`, and `plugins/remem/apps/remem/`.
- Plugin distribution: keep these in sync when versions change:
  - `Cargo.toml`
  - `Cargo.lock`
  - `plugins/remem/.codex-plugin/plugin.json`
  - `plugins/remem/runtimes/remem-releases.json`
  - `npm/remem/package.json`

## Commands

Before opening or updating a PR, run the local preflight so CI gate failures are
reported together instead of one push at a time:

```bash
python3 scripts/ci/check_pr_preflight.py --base origin/main --pr-body-file /tmp/pr-body.md
```

Use `--fast` for the mechanical subset while iterating, then run the full
preflight before merge readiness. `--pr-body-file`, `--pr-title` and
`--skip-pr-body-checks` are accepted for compatibility but no longer feed any
check, so the preflight does not validate PR-body governance.

Before completion for code changes:

```bash
cargo fmt --check
cargo check
```

Before submission or when touching shared runtime behavior:

```bash
cargo test
```

For task work, run the gate instead of the individual commands. It is the
referee `/task:orchestrate` grades against, so running it yourself means no
surprises at the phase boundary:

```bash
scripts/gate.sh --task R0-02          # full tier, before the PR
scripts/gate.sh --task R0-02 --quick  # per-task tier, defers cargo test
```

It exits `0` on pass, `1` on failure, and `2` when a check could not run at all
- which is never a pass. It prints the task file's acceptance criteria but does
not run them; those are yours.

CI also runs:

```bash
python3 scripts/ci/check_plugin_version_sync.py
node --test plugins/remem/scripts/remem-runtime.test.js plugins/remem/apps/remem/server.test.js npm/remem/scripts/install.test.js
python3 scripts/ci/check_version_bump.py <base-sha> HEAD
cargo run -- eval-extraction --json --check-baseline
cargo run -- eval-gates --json-out /tmp/remem-eval-gates.json
cargo clippy --all-targets -- -D warnings
```

Use focused tests first for narrow fixes, then the broader gate when practical. Do not claim completion from earlier or unrelated output.

## Documentation Rules

- Keep root Markdown limited to entry, governance, and contribution docs, plus
  `project.md`. The board is deliberately at the root because it is the first
  file to read and the one `docs/tasks/README.md` points at for status; it is
  the single exception, not licence for more.
- Put current implementation specs under `docs/specs/`; add an index/status entry when adding a spec.
- Put research/comparison/marketing material under `docs/research/`, `docs/analysis/`, or `docs/marketing/`.
- Do not silently modify high-context files (`AGENTS.md`, `CLAUDE.md`, plugin skills, hooks/config docs) through generators or dependency output.
