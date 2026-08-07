# docs/tasks - Executable task files

One file per task. Each is independently grabbable: it names its blockers, the
verified code reality it depends on, and acceptance criteria you can run.

Status lives in `project.md` at the repository root, not here. These files are
the contract; that file is the board. The rules for working one - how the gate
grades it, when to defer a defect rather than fix it, what counts as evidence -
are in [`docs/plan/20-rename-and-release/conventions.md`](../plan/20-rename-and-release/conventions.md).

`/task:orchestrate R0-NN` runs a task file end to end. It treats the file as the
approved spec, so there is no spec phase to sit through; the acceptance criteria
below become Layer 1 of the validation gate.

## Conventions

- Filename: `r<item>-<nn>-<short-slug>.md`, ordered by dependency, not priority.
- **Type AFK**: implementable and mergeable without a human decision.
  **Type HITL**: needs your account, your machine, or your judgement.
- Acceptance criteria are commands with expected results, not descriptions. A
  criterion nobody can run is a bug in the task.
- Context sections record what was verified in the code, with file and line
  references. They are not restatements of the plan.

## Reading a task before starting it

The Context section is where the traps are. Every one of them was found by
inspecting the repository, and several contradict what the plan looked like
before that inspection:

- R0-01 must precede R0-02 because the mandated preflight invokes scripts R0-02
  deletes. **Satisfied** - R0-01 is merged, so R0-02 is clear to start.
- R0-00 existed because GitHub Actions had never run here. Six acceptance
  criteria across R0-02, 04, 05, 06, and 07 read "on a pull request, X runs and
  passes", and none could be met while nothing started. **Satisfied** - the
  fork-inherited gate was cleared 2026-08-07 (the task file records the cause),
  the four hazardous workflows were disabled first, and `auto-release.yml` has
  zero runs despite its trigger having since fired.
- R0-04 is blocked by R0-05 because branch protection pins a status check by
  name, and R0-05 renames the job. Applying it before R0-00 would pin a check
  that never reports, blocking every merge to `main` permanently.
- R0-08's acceptance criteria require the audit to **fail** on the current tree.
  That is the point: an audit nobody has seen fail proves nothing.
- R0-11 exists because there is no export subcommand for an extraction task, so
  the snapshot is the only way to keep R1's replay target.
- R0-16 exists because the plugin resolver returns `null` for an unreleased
  manifest before it ever reads a base URL.

## Current work item

R0, the rename and release contract. Spec: `docs/plan/20-rename-and-release/`.

| Phase | Tasks | Theme |
|---|---|---|
| 0 | 01-04 | Governance trim and repository protection |
| 1 | 05-07 | CI rebuilt, Rust first, hosted macOS |
| 2 | 08-10 | Rename, manifest-driven and audited |
| 3 | 11-13 | Recoverable local cutover |
| 4 | 14-18 | Release, staged then published |

**R0-11 is complete.** The snapshot exists at `~/Backups/recol/2026-07-31/`,
proven to restore byte for byte and to open with no Keychain lookup. Do not
rerun it: a second run would take a fresh baseline from a source that has since
been read, and would overwrite a verified artifact with an unverified one. If
you need the old installation, restore it - `RESTORE.md` is in that directory.

**R0-01 is complete**, merged as PR #1. Its five acceptance criteria are green
and the preflight no longer invokes the three scripts R0-02 deletes.

**R0-00 is complete**, merged as PR #3. Actions runs: pull request runs are
red at the inherited "Resolve linked issue" step until R0-02 deletes it, and
pushes to `main` are green because every governance step is gated on
`pull_request`.

**Start with R0-02.** Its blockers, 00 and 01, are both done, and it removes
what keeps every pull request red.

A warning from running it: R0-02's diff came to roughly three times its Scope
checklist. The scope and the acceptance criteria were both drawn from the same
survey of `.github/` and `scripts/`, so the criteria inherited the survey's
blind spot - every one of them passed green over a tree containing a module
that imported a deleted package. Searching outside those paths found `tools/`,
`skills/`, `AGENT_USAGE.md`, `templates/`, `review/`, `integrations/`, root
`schemas/` and `artifacts/`. When a task's criteria search only where its scope
was drawn from, they cannot detect an incomplete scope. Read the file lists in
`docs/plan/` as a starting survey, not a complete one.

**03 and 08 are unblocked** and depend on none of this, so they can run
alongside R0-02.
