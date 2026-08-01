# docs/status - Workflow state

One YAML file per issue, recording where that issue sits in the task lifecycle.
`/task:orchestrate REC-XX` reads this file to decide which phase to resume and
writes it back after each transition.

These files are machine-written. Editing one by hand changes what the next
`/task:orchestrate` run believes has already happened, which is occasionally
what you want when a phase half-completed, and otherwise a way to skip a
checkpoint by accident.

## Conventions

- Filename: `rec-<issue-number>-workflow.yaml`.
- The template that seeds a new file is `.claude/templates/workflow-state.yaml`.

## Relationship to `project.md`

`project.md` at the repository root is the board: what is done, what blocks
what, what to do next, maintained by hand and written for a person. This
directory is per-issue execution state, written for a command. When they
disagree, `project.md` is the one a human decided.
