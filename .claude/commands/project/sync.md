# /project:sync - Apply a task state change to the local tracker

**Purpose**: Keep `docs/project.md` consistent with Linear when a task starts, finishes, or changes its blockers.

**Usage**:
- `/project:sync REC-XX --start`
- `/project:sync REC-XX --complete`
- `/project:sync REC-XX --complete "Summary text"`
- `/project:sync REC-XX --block REC-YY`
- `/project:sync REC-XX --unblock`

---

## This repo has ONE aggregation file

`docs/project.md`. There is no `PROJECT.md`, no `ROADMAP.md`, no `DEPENDENCIES.md` - do not create them, do not look for them, do not report them as missing. Earlier versions of this command assumed all three; every run had to work around their absence.

`docs/project.md` is not a set of tables. It is:

| Part | What it is |
|---|---|
| `**Last updated**:` line | One line, bumped on every edit |
| `## Status summary` | Prose bullets, including a `WIP: n/5` count |
| Dependency **trees** | ASCII trees with status emoji per node |
| `## Connections and dependencies` | Every edge with the reason it exists |
| `**Critical path**:` line | One prose line naming the current gate |

Edits are surgical changes to prose and trees, not row insertions.

**Legend**: ✅ done · 🔄 in progress · ⚪ ready · 🔒 blocked · ⬜ backlog · ✳️ epic · ⏸ hold

---

## Epics

An epic is an ordinary Linear issue titled `EPIC E<n>: ...`, drawn as `✳️`, whose body links its children. Linear has no native epics.

- **Never sync an epic directly.** `--start` or `--complete` on a `✳️` node is an error: reply that epic state is derived from children and ask which child was meant.
- An epic is 🔄 once any child is 🔄, and ✅ only when every child is ✅.
- On `--complete` of a child, re-evaluate its epic. If it was the last open child, say so and offer to close the epic in Linear.
- A child under two epics (currently REC-578) lives in one place and is cross-referenced from the other. Never duplicate its node.

---

## Step 1: Read before writing

1. Read `docs/project.md` in full. Never edit it from memory - other sessions change it.
2. Fetch the issue with `mcp__linear-server__get_issue` for title, state and labels.
3. Locate the task's node in the tree. Not found → stop and ask where it belongs rather than appending it somewhere plausible.

---

## Action: --start

**Validate**

- **WIP limit.** Count 🔄 nodes across all trees. The summary line says `WIP: n/5`. At 5, list them and ask which to pause. Do not proceed unasked.
- **Blockers.** If the node is 🔒, or `## Connections and dependencies` lists an incomplete blocker, report it and stop. Starting a blocked task is the error this check exists to catch.
- **Epic guard.** `✳️` node → refuse per *Epics* above.

**Apply**

1. Node emoji → 🔄.
2. If its epic is not already 🔄, set it.
3. Update the `WIP: n/5` count in the status summary.
4. If this task is the current gate, update the `**Critical path**:` line.
5. Bump `**Last updated**:` with a short parenthetical.
6. Set the Linear issue to In Progress.

---

## Action: --complete

**Apply**

1. Node emoji → ✅. Append the merge evidence inline: `(PR #NN, done MM-DD)`.
2. **Flip what it unblocked.** For every node whose only blocker was this task, 🔒 → ⚪. Consult `## Connections and dependencies` for the real edges - the tree draws them but that section states them.
3. **Re-evaluate the epic.** All children ✅ → mark the epic ✅ and offer to close it in Linear.
4. Update the `WIP: n/5` count.
5. Update the `**Critical path**:` line if the gate moved.
6. Add a status-summary bullet only if the task carries a finding worth keeping. Routine completions do not need one; the tree already records them.
7. Bump `**Last updated**:`.
8. Set the Linear issue to Done.

**Verify before claiming done.** If the task asserts something observable - an endpoint, a screen, a deploy - check it rather than trusting the merge. On 2026-07-26, REC-562 sat merged-but-undeployed for a day because a post-merge `startup_failure` published no image, and REC-560 was marked complete while `/exercise` still 404'd because the rsync had never been run. A merged PR is not a working feature.

---

## Action: --block REC-YY

1. Verify REC-YY exists in Linear.
2. Node emoji → 🔒.
3. Add the edge to `## Connections and dependencies` **with its reason**. An edge whose reason cannot be stated should not be added - ask instead.
4. Add `blockedBy` on the Linear issue.
5. Bump `**Last updated**:`.

---

## Action: --unblock

1. Node emoji 🔒 → ⚪.
2. Remove the edge from `## Connections and dependencies`, or state why it no longer holds.
3. Remove the relation in Linear with `removeBlockedBy`.
4. Bump `**Last updated**:`.

---

## Output

Report what changed and what it unblocked. Keep it short:

```
REC-576 complete

docs/project.md
  REC-576  ⚪ -> ✅  (PR #91, done 07-28)
  REC-568  🔒 -> ⚪   unblocked
  REC-570  🔒 -> ⚪   unblocked
  WIP 2/5 -> 1/5
  epic REC-581: 3 of 4 children done

Linear
  REC-576 -> Done

Next: REC-568 and REC-570 are both ready.
```

---

## Errors

| Case | Response |
|---|---|
| Issue not in Linear | Report the ID and stop. Do not create it. |
| Node absent from `docs/project.md` | Ask where it belongs. Do not guess a parent. |
| Already in target state | Say so and make no edit. Idempotent. |
| `--start` on an epic | Refuse; ask which child. |
| File changed since read | Re-read and re-apply. Never overwrite from memory. |

---

## Does not

- Create the three aggregation files. They do not exist here by design.
- Modify Linear beyond the state and relation changes named above.
- Skip the WIP or blocker check.
- Mark work complete on the strength of a merge alone.
