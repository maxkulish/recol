# Phase: Blocked

**Purpose**: Handle blockers from any phase, sync project files, and support recovery when blockers are resolved.

**Entry conditions**: `workflow.status: blocked` (can occur from any phase)

---

## Entering Blocked State

If any phase encounters a blocker (e.g., dependency on another task, external resource unavailable):

### Step 1: Identify the Blocker

- If blocked by another task: Note the blocking task ID (e.g., REC-YY)
- If external blocker: Document the issue

### Step 2: Sync Project Files (if blocked by another task)

- **Invoke**: `/project:sync <task-id> --block <blocker-id>`
- That command adds the blocker to the task's `Blocked by` cell in `project.md`
  and mirrors the edge into the dependency graph below the table.

### Step 3: Update Workflow State

- `workflow.status: blocked`
- Add blocker details to history: `workflow_blocked`

### Step 4: Display

```
WORKFLOW BLOCKED

Task: REC-XX
Phase: [current phase]
Blocked By: REC-YY ([blocker status])
Reason: [description]

Resolution needed:
1. Complete REC-YY first, OR
2. Remove the blocking relationship if no longer valid

After resolving, run: /task:orchestrate REC-XX
```

---

## Recovery (Resuming a Blocked Workflow)

When resuming a blocked workflow:

### Step 1: Check if Blocker is Resolved

- File-based track: check the blocker's Status cell in `project.md`, and confirm
  its acceptance criteria actually ran. `done` on the board is a claim; the
  task's own criteria are the evidence.
- Linear track: query the blocker with `mcp__linear-server__get_issue`

### Step 2: If Resolved

- **Invoke**: `/project:sync REC-XX --unblock`
- Update workflow state: `workflow.status: in_progress`
- Add history entry: `workflow_unblocked`
- Continue from blocked phase

### Step 3: If Not Resolved

- Display blocker status again
- Offer options:
  ```
  STILL BLOCKED

  Task: REC-XX
  Blocked By: REC-YY ([current status])

  Options:
  1. [wait] - Check again later
  2. [override] - Remove blocker and proceed (use with caution)
  3. [cancel] - Cancel this workflow

  Your choice:
  ```
