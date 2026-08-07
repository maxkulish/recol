# /project:sync - Apply a task state change to the local tracker

**Purpose**: Keep `project.md` consistent with what actually happened when a task starts, finishes, or changes its blockers.

**Usage**:
- `/project:sync R0-02 --start`
- `/project:sync R0-02 --complete`
- `/project:sync R0-02 --complete "Summary text"`
- `/project:sync R0-02 --block R0-05`
- `/project:sync R0-02 --unblock`

Task refs come in two shapes. `R<n>-<nn>` is file-based and lives in `docs/tasks/`; `REC-<n>` is a Linear issue. Only the file-based shape appears on this board today. A Linear-tracked ref does everything below **and** sets the issue state; a file-based ref has no Linear side and must not be reported as missing one.

---

## This repo has ONE aggregation file

`project.md`. There is no `PROJECT.md`, no `ROADMAP.md`, no `DEPENDENCIES.md` - do not create them, do not look for them, do not report them as missing. Earlier versions of this command assumed all three; every run had to work around their absence.

Read it before editing. It is not a set of interchangeable tables:

| Part | What it is |
|---|---|
| `Last updated: <date>.` | One plain line near the top. Not bold, not a field |
| `## Done` | Two-column table, `\| \| Evidence \|`. The left cell is a claim, the right is how you know |
| `## Next` | Prose. Which task to start and what would go wrong otherwise |
| `## R0 - ...` | The task table: `\| Task \| Type \| Blocked by \| Status \|` |
| The fenced ASCII graph under it | Numeric dependency edges: `01 -> 02`, `00 gates 02, 04, ...` |
| `## Roadmap after R0` | Post-R0 items with a blocked-by and a class |
| `## Working constraints` | Settled facts. Never edited by this command |

**Task rows** link the task file: `| [02 Delete governance machinery](docs/tasks/r0-02-delete-governance.md) | AFK | 00, 01 | todo |`. `Blocked by` holds bare task numbers, not full ids. `Type` is `AFK` or `HITL` and comes from the task file.

**Status vocabulary**: `todo` -> `doing` -> `done`, plus `**next**` on exactly one row, marking the recommended starting point. `doing` was added when `/task:orchestrate` needed a way to say "in flight": the board previously had no in-progress state, and reusing `**next**` for it would have made "what should I start" unanswerable while work was underway.

Edits are surgical changes to specific cells and prose, not rewrites.

---

## Step 1: Read before writing

1. Read `project.md` in full. Never edit it from memory - other sessions change it.
2. Read the task file at `docs/tasks/<task-id>-*.md` for its Goal, Type, and `Blocked by:` line. For a Linear ref, fetch the issue with `mcp__linear-server__get_issue` instead.
3. Locate the task's row. Not found -> stop and ask where it belongs rather than appending it somewhere plausible.
4. Check the row's `Blocked by` against the task file's `Blocked by:` line. They disagree only when one of them was not updated; say which you trust and why before editing either.

---

## Action: --start

**Validate**

- **Blockers.** Every task number in the row's `Blocked by` cell must be `done`. If any is not, report which and stop. Starting a blocked task is the error this check exists to catch, and `docs/tasks/README.md` records that several R0 dependencies are real rather than advisory.
- **Already `doing`.** Another task in flight is not an error here - the board has no WIP ceiling - but say how many rows are `doing` so the human can decide.

**Apply**

1. Status cell -> `doing`.
2. If this task is now the obvious starting point and no other row holds it, move the `**next**` marker.
3. Update `## Next` only if the prose it contains is now wrong. It argues a case; do not append a status line to it.
4. Bump `Last updated:`.
5. Linear ref only: set the issue to In Progress.

---

## Action: --complete

**Apply**

1. Status cell -> `done`.
2. **Add a `## Done` row.** Left cell is what is now true, right cell is the evidence: the PR link and merge SHA, which acceptance criteria went green, and any finding worth keeping. Rows already there set the bar - they cite run counts, SHAs, and what a failure taught.
3. **Flip what it unblocked.** For every row whose `Blocked by` listed only this task, it is now startable. Move `**next**` if the gate moved.
4. **Check the ASCII graph.** It encodes the same edges as the `Blocked by` column. If completion changed the shape of the work - a task turned out not to gate what the graph says - fix the graph in the same edit, or the two disagree silently.
5. Update `## Next` if the critical path moved. This is prose: rewrite the paragraph, do not bolt a sentence onto it.
6. Bump `Last updated:`.
7. Linear ref only: set the issue to Done.

**Verify before claiming done.** If the task asserts something observable - a workflow that runs, an installed binary, a published release - check it rather than trusting the merge. On 2026-07-26, REC-562 sat merged-but-undeployed for a day because a post-merge `startup_failure` published no image, and REC-560 was marked complete while `/exercise` still 404'd because the rsync had never been run. A merged PR is not a working feature.

Acceptance criteria are the specific form of that check here: the task file states them as commands with expected results. `--complete` on a task whose criteria were never run is the same mistake with better paperwork.

---

## Action: --block R0-YY

1. Verify R0-YY has a row (or a Linear issue, for a Linear ref).
2. Add its number to the task's `Blocked by` cell.
3. Add the edge to the ASCII graph **with the same direction the cell states**.
4. Say in the output why the edge exists. An edge whose reason cannot be stated should not be added - ask instead.
5. Bump `Last updated:`.
6. Linear ref only: add `blockedBy` on the issue.

---

## Action: --unblock

1. Remove the number from the `Blocked by` cell.
2. Remove the corresponding edge from the ASCII graph.
3. State why it no longer holds.
4. Bump `Last updated:`.
5. Linear ref only: remove the relation with `removeBlockedBy`.

---

## Output

Report what changed and what it unblocked. Keep it short:

```
R0-02 complete

project.md
  R0-02  doing -> done   (PR #4, merged 8f21ac3)
  R0-05  blocked -> startable   (00, 02, 03 all done)
  Done   + "Governance machinery deleted"
  next   R0-00 -> R0-05

Next: R0-05 is the CI rebuild and gates 04, 06, 07.
```

---

## Errors

| Case | Response |
|---|---|
| Row absent from `project.md` | Ask where it belongs. Do not guess a position. |
| Task file absent from `docs/tasks/` | Report the glob that found nothing and stop. |
| Already in target state | Say so and make no edit. Idempotent. |
| `Blocked by` names an unfinished task | Refuse `--start`; list which. |
| Row and task file disagree on blockers | Report both, ask, edit neither. |
| File changed since read | Re-read and re-apply. Never overwrite from memory. |

---

## Does not

- Create the three aggregation files. They do not exist here by design.
- Touch `## Working constraints`. Those are settled facts, not task state.
- Rewrite `## Next` wholesale. It is an argument; amend it where it became wrong.
- Report a missing Linear issue for a file-based task. That track has none.
- Skip the blocker check.
- Mark work complete on the strength of a merge alone.
