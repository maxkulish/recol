# docs/tasks - Executable task files

One file per task. Each is independently grabbable: it names its blockers, the
verified code reality it depends on, and acceptance criteria you can run.

Status lives in `project.md` at the repository root, not here. These files are
the contract; that file is the board.

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
  deletes.
- R0-04 is blocked by R0-05 because branch protection pins a status check by
  name, and R0-05 renames the job.
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

Four tasks have no blockers and can start immediately: **01, 03, 08, and 11**.

Start with **R0-11**. It is the only task that protects against every other task
going wrong, and it touches nothing the others need.
