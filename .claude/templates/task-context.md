# Task Context

Shared prelude for the task commands. Referenced, not copied - three commands
carried their own copy of this table and all three said Linear was the only
track, which stopped being true when R0 moved to `docs/tasks/`.

## Two task tracks

| Ref shape | Track | Requirements live in | Board |
|---|---|---|---|
| `R<n>-<nn>` | File-based | `docs/tasks/r<n>-<nn>-*.md` | `project.md` |
| `REC-<n>` | Linear | The Linear issue (workspace `cloud-ai`) | `project.md` + Linear state |

Resolve the track from the ref shape before anything else. A file-based ref that
matches no file is an error - report the glob that found nothing and stop. Do
not fall through to Linear: R0 tasks are not there, so "issue not found" would
misdiagnose a typo.

`<task-id>` throughout means the ref lowercased: `r0-02`, `rec-9`. It names the
state file (`docs/status/<task-id>-workflow.yaml`), the review reports, and the
branch.

On the file-based track the task file **is** the spec. It carries a Goal, a
Scope checklist, and acceptance criteria written as runnable commands, so there
is nothing for a spec or design phase to author. `linear_url: null` is a valid
state, not a gap to explain.

## Branch naming

`<type>/<task-id>-<short-kebab-title>` where `<type>` is the conventional commit
type the work will use: `feat`, `fix`, `chore`, and `docs` or `build` where they
fit.

Keep the title to two to four words - `feat/rec-515-status`, not
`feat/rec-515-add-status-command-with-cache-metrics`.

Never use Linear's suggested branch name. It is username-prefixed and carries
the full issue title (`kmamemo/<issue-id>-<full-title>`); rename it to the
convention before pushing.

## Verification

`scripts/gate.sh --task <task-id>` is the referee. It runs `cargo fmt`,
`cargo check`, `cargo test`, and a `yaml.safe_load` sweep, and it prints the task
file's acceptance criteria, which you run yourself. `--quick` defers `cargo test`
to the phase boundary.

Exit `0` pass, `1` fail, `2` a check could not run - which is never a pass.

The round's working rules are in
`docs/plan/20-rename-and-release/conventions.md`.
