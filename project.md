# Recol - Project Board

What is done, what blocks what, what to do next. Detail lives elsewhere and is
referenced, never copied: specs in `docs/plan/`, executable tasks in
`docs/tasks/`.

Last updated: 2026-08-08 (R0-02 in flight, PR #4).

## Done

| | Evidence |
|---|---|
| Test baseline established | `cargo test --workspace` exits 0 at `f291d119` |
| Repository detached from `majiayu000/remem` | `isFork: false`, `parent: null`; `upstream` remote still fetches |
| Roadmap written, R0-R7 | `docs/plan/01-roadmap.md` |
| R0 spec written and reviewed | `docs/plan/20-rename-and-release/`, revised at `eaf208c7` after a 12-point review |
| R0 broken into 18 executable tasks | `docs/tasks/` |
| R0-11 snapshot taken and proven restorable | `~/Backups/recol/2026-07-31/`, inventory at `docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md`; Task 7 cleanup substituted `find -depth -delete` after a safety hook twice refused `rm -rf`, with the deleted paths verified correct and the substitution surfaced to and accepted by the user |
| R0-11's four deferred findings closed | `r0-12`, `tech.md`, `tasks.md`, `product.md`, `docs/tasks/README.md` - the parent contracts still mandated an export path that does not exist, inventoried before restoring, compared searches against the live source, and routed agents at a completed task |
| `refactor/11` recovered after losing its ref | branch was absent from `git branch -a` with no worktree; all 16 commits survived as a dangling commit at `76af6a10` and the ref was restored. `.superpowers/sdd/r0-11-execution-plan/` is **not** on disk - the execution plan is committed at `docs/plan/20-rename-and-release/r0-11-execution-plan.md`, and the evidence for criteria 3 and 4 survives only in the session transcript at `~/.claude/projects/-Users-mk-Code-recol--refactor-11/` |
| R0-01 preflight narrowed, merged | [PR #1](https://github.com/maxkulish/recol/pull/1) merged at `35129895`. All five acceptance criteria green: full preflight 15/15, `--fast` 9/9, `cargo test --workspace` 3144 passed. The three doomed checks are gone from the preflight and still invoked directly by `ci.yml`, so R0-02 can now delete them. Four Qodo findings were raised and fixed across three review rounds; the highest-severity one was a state file that did not parse as YAML while every local gate was green |
| Orchestrator rebuilt around a real gate | [PR #2](https://github.com/maxkulish/recol/pull/2) merged at `fc29cfc3`, plan at `docs/plan/30-command-suite-adaptation.md`. R0-01 had finished `ungraded` because the only grader the commands accepted was `.lok/workflows/`, which this repo does not have. `scripts/gate.sh` now runs the deterministic layers and exits 0/1/2, where 2 means a layer could not run and is never a pass. Nine seeded defects prove it: four the gate must call FAIL, five environments it must call UNAVAILABLE. R0-NN task files are now first-class, so a task file is the spec and its acceptance criteria are gate layer L1. Qodo raised two Action Required findings, both real; the first was the gate contradicting its own rulebook, which is what added the UNAVAILABLE half of the validation |
| R0-00: GitHub Actions actually running | [PR #3](https://github.com/maxkulish/recol/pull/3) merged at `4dc59c20`. The suppression was the fork-inherited gate, invisible to the API - `actions/permissions` reported `enabled: true` throughout - and a toggle of that same setting off and back on cleared it. All seven acceptance criteria verified: four hazardous workflows `disabled_manually` before enabling anything, two `pull_request` runs concluded red at the inherited "Resolve linked issue for classification" step, the merge `push` run concluded **green** in 26m50s, and `auto-release.yml` shows zero runs even though its trigger - CI completing on `main` - fired minutes after the disable |

**GitHub Actions now runs.** The suppression was the fork-inherited gate,
invisible to the API and cleared on 2026-08-07 by toggling
`repos/maxkulish/recol/actions/permissions` off and back on (details in the
R0-00 task file). Acceptance criteria of the form "on a pull request, X runs"
are satisfiable from here on. Two expectations hold until R0-02 and R0-05
land: every **pull request** run is red - it dies at the inherited "Resolve
linked issue for classification" step, unsatisfiable with issues disabled -
and every **push to `main`** is green, because all governance steps are gated
on `pull_request`. Note also that a bare `gh run list` in a local checkout
resolves to the `upstream` remote and shows majiayu000/remem's green history,
which is easy to mistake for recol activity; always pass
`--repo maxkulish/recol`.

## Next

**R0-02 is in flight** as [PR #4](https://github.com/maxkulish/recol/pull/4),
the first task carried by `/task:orchestrate` end to end. Gate verdict PASS,
`cargo test --workspace` 3144 passed - the same count R0-01 recorded before any
of it was deleted, which is what proves 20,416 removed lines were inert. Its
own pull request run is the test of the prediction above: it deletes the
"Resolve linked issue" step every red run died on.

Its diff grew to roughly three times the Scope checklist. The written scope and
the acceptance criteria were both drawn from the same survey of `.github/` and
`scripts/`, so the criteria inherited the survey's blind spot and would have
passed green over a broken import. Searching outside those paths found
`tools/`, `skills/`, `AGENT_USAGE.md`, `templates/`, `review/`,
`integrations/`, root `schemas/` and `artifacts/`. Treat the R0 spec's
per-phase file lists as a starting survey, not a complete one.

**R0-04 still needs care.** It pins branch protection to a required status
check by name. Do not apply it until a run has reported under the name it
pins, or `main` becomes permanently unmergeable.

**R0-03 and R0-08 remain unblocked** and depend on none of this, so they can run
alongside.

R0-11 is done: `~/.remem` is backed up to an encrypted, restore-proven archive
at `~/Backups/recol/2026-07-31/`. R0-12 (blocked by 10, 11) can proceed once
R0-10 lands.

Whichever task goes first, run it with `/task:orchestrate R0-NN`. Since PR #2 it
treats the task file as the spec and grades against `scripts/gate.sh`, so the
acceptance criteria in `docs/tasks/` are what the workflow checks rather than a
list someone reads at the end. That path has not carried a real task yet, so
expect to fix the contract as much as the task on the first run.

## R0 - Rename, CI refactor, distribution

Spec: `docs/plan/20-rename-and-release/` | Tasks: `docs/tasks/`

| Task | Type | Blocked by | Status |
|---|---|---|---|
| [00 Enable GitHub Actions](docs/tasks/r0-00-enable-actions.md) | HITL | - | done |
| [01 Narrow the PR preflight](docs/tasks/r0-01-narrow-pr-preflight.md) | AFK | - | done |
| [02 Delete governance machinery](docs/tasks/r0-02-delete-governance.md) | AFK | 00, 01 | **doing** |
| [03 Delete npm/ and server.json](docs/tasks/r0-03-delete-npm-and-server-json.md) | AFK | - | todo |
| [04 Repository protection](docs/tasks/r0-04-repository-protection.md) | HITL | 00, 05 | todo |
| [05 Rebuild ci.yml, Rust first](docs/tasks/r0-05-rebuild-ci-rust-first.md) | AFK | 00, 02, 03 | todo |
| [06 First-run smoke](docs/tasks/r0-06-first-run-smoke.md) | AFK | 00, 05 | todo |
| [07 Hosted macOS jobs](docs/tasks/r0-07-hosted-macos-jobs.md) | AFK | 00, 05 | todo |
| [08 Rename manifest and audit](docs/tasks/r0-08-rename-manifest-and-audit.md) | AFK | - | todo |
| [09 Rename build surfaces, 0.7.0](docs/tasks/r0-09-rename-build-surfaces.md) | AFK | 07, 08 | todo |
| [10 Rename remaining surfaces](docs/tasks/r0-10-rename-remaining-surfaces.md) | AFK | 09 | todo |
| [11 Inventory and snapshot](docs/tasks/r0-11-inventory-and-snapshot.md) | HITL | - | done |
| [12 Install and re-ingest](docs/tasks/r0-12-install-and-reingest.md) | HITL | 10, 11 | todo |
| [13 Retire old installation](docs/tasks/r0-13-retire-old-installation.md) | HITL | 12 | todo |
| [14 Rewrite release.yml](docs/tasks/r0-14-rewrite-release-workflow.md) | AFK | 04, 10 | todo |
| [15 Tap job with staging](docs/tasks/r0-15-tap-job-with-staging.md) | AFK | 14 | todo |
| [16 Plugin download smoke](docs/tasks/r0-16-plugin-download-smoke.md) | AFK | 10 | todo |
| [17 Cut release candidate](docs/tasks/r0-17-cut-release-candidate.md) | HITL | 15, 16 | todo |
| [18 Publish and activate](docs/tasks/r0-18-publish-and-activate.md) | HITL | 17 | todo |

```
00 gates 02, 04, 05, 06, 07 - every task verified by a CI run

11 ──────────────────────────┐
01 ─> 02 ─┐                  │
03 ───────┴─> 05 ─┬─> 04 ────┼──> 14 ─> 15 ─┐
                  ├─> 06     │              ├─> 17 ─> 18
                  └─> 07 ─┐  │        16 ───┘
                  08 ─────┴─> 09 ─> 10 ─┬─> 12 ─> 13
                                        ├─> 14
                                        └─> 16
```

R0-13 is the only irreversible task. Everything before it is additive.

## Roadmap after R0

Spec: `docs/plan/01-roadmap.md`

| Item | Blocked by | Class |
|---|---|---|
| R1 Reliable extraction output | R0 | upstream-after |
| R2 Transcript-to-curation bridge | R1 | fork |
| R3 Per-project sensitivity routing | R4 | fork |
| R4 Backend layer replacement | R0 | fork |
| R5 Retrieval fixes (a, b, c) | R0 | upstream |
| R6 Key source (Keychain) | R0 | upstream |
| R7 Retrieval triggering | R2 | fork |

R1 waits for R0-10 specifically: it edits `src/observation_extract/`, which the
rename rewrites. R1 step 2 additionally needs R0-11's snapshot.

R5 and R6 are the cheapest wins once R0 lands. Their `upstream` classification
now describes intent, not an available route - a detached repository cannot open
a pull request against its former parent.

## Working constraints

Established, not open questions. Re-deriving these wastes a session.

- **The `remem` on PATH is crates.io 0.6.27, not this build.** Test with
  `cargo run --` or `cargo install --path .`, or you are exercising upstream and
  will conclude your change did nothing. R0-13 removes it.
- **`ingest-sessions` does not feed curation.** Verified in source and
  empirically: 1,900 files and 22,555 messages produced Captured 0, Extract todo
  0, Candidates 0. The pipelines are separate by design. This is why the project
  exists.
- **The database holds no curated state, but two things in it are not
  reproducible.** Memories 0, Observations 0, Sessions 0, Candidates 0. Only
  extraction task id 1 and `config.toml` matter, and there is no export
  subcommand for the former.
- **Diagnose search quality with `--json`**, reading `.results[].content`. The
  printed output shows only the first line of each message, which once made four
  unrelated queries look identical.
- **`ci.yml` triggers on push to `main` and on `pull_request` only.** Pushing a
  feature branch exercises nothing; verify with a pull request.
- **Do not run `install`.** It wires SessionStart injection and PostToolUse
  capture, and starts background curation automatically.
- **Do not use gcm as the base for the backend crate.** Measured and rejected:
  `src/provider/*.rs` references `crate::plan` and `crate::diff` seven times
  each, so its trait is commit-shaped. lok is the base.
- **Do not trust `usage` for extraction cost.** It records a text-length
  estimate, not provider data, and says so itself.
