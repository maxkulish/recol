# Phase: Initialize / Resume Workflow

**Purpose**: Parse arguments, initialize new workflows or resume existing ones, classify task type, and sync project aggregation files.

**Called by**: `/task:orchestrate` dispatcher

---

## Step 1: Parse Arguments

1. **Extract the task ref and resolve its track.** Two tracks exist and they
   differ in where the requirements live:

   | Ref shape | Track | Requirements come from |
   |---|---|---|
   | `REC-<n>` / `rec-<n>` | Linear | `mcp__linear-server__get_issue` |
   | `R<n>-<nn>` / `r<n>-<nn>` | File-based | `docs/tasks/r<n>-<nn>-*.md` |

   Everything downstream uses `<task-id>`, the ref lowercased: `rec-9`, `r0-02`.
   The state file is `docs/status/<task-id>-workflow.yaml` on both tracks.

   A file-based ref matching no file is an error: report the glob that found
   nothing and stop. Do not fall through to Linear - R0 tasks are not in Linear,
   so a "not found" from Linear would misdiagnose a typo as a missing issue.

2. **Check for flags**:
   - `--status`: Display current state and exit (load `phases/status.md`)
   - `--ops`: Force operational task type (skip design/plan phases)
   - `--spec`: Force specification task type (use /spec instead of full design doc)
   - `--skip-discovery`: Skip discovery phase for development tasks (go straight to design)
3. **If no task provided**: Ask user interactively

---

## Step 2: Initialize or Resume Workflow

### Check for Existing Workflow State

Derive done-ness from disk first. The state file is an audit trail, not the
authority: it is written by hand and can be stale, truncated, or - as on R0-01 -
unparseable while every other check is green.

```bash
ls docs/status/<task-id>-workflow.yaml 2>/dev/null   # state file
ls docs/tasks/<task-id>-*.md 2>/dev/null             # task file (file-based track)
git log --oneline main..<branch> 2>/dev/null         # commits that exist
gh pr list --search "<task-id>" --state all --json number,state,url
```

**If workflow state exists**:
1. Read `docs/status/<task-id>-workflow.yaml`. If it does not parse as YAML, say
   so and repair it before anything else - do not work around it.
2. **Reconcile it against disk.** Where the two disagree, disk wins and the YAML
   is corrected: a `pr` phase with no PR on GitHub is not complete; commits
   present but absent from `phases.implement.commits` get backfilled; a
   `plan_file` that no longer exists is null.
3. Display the current state summary, naming any field disk corrected.
4. Ask: "Resume from [current phase]? (yes/restart/cancel)"
   - **yes**: Continue from current phase
   - **restart**: Reset workflow to beginning
   - **cancel**: Exit

**If workflow state does NOT exist**:
1. Create new workflow state file from `.claude/templates/workflow-state.yaml`
2. Load the requirements for the track resolved in Step 1:
   - **Linear**: fetch with `mcp__linear-server__get_issue`; set `linear_url`
   - **File-based**: read `docs/tasks/<task-id>-*.md`; set `linear_url: null`,
     which is a valid state and not a gap to explain. See Step 2.4.
3. **Classify task type**: Proceed to Step 2.3
4. Initialize phases based on task type
5. Set initial phase and status
6. **Sync project files**: Proceed to Step 2.5

---

## Step 2.3: Classify Task Type (New Workflow Only)

1. **If `--ops` flag provided**: Set `task_type: operational`
2. **If `--spec` flag provided**: Set `task_type: specification`

2b. **If the track is file-based**: set `task_type: specification` without
   asking. The task file already contains everything the spec phase would
   produce - a Goal, a Scope checklist, and acceptance criteria written as
   runnable commands - so writing a spec for it would be transcription. Skip
   the classification questions below and go to Step 2.4.

   The one thing to read off the task file is its `Type:` line: `HITL` means a
   human runs at least one criterion, so the workflow must reach the checkpoint
   rather than driving to a PR unattended. Record it in
   `phases.spec.execution_mode`.

3. **Otherwise, analyze task**:
   - Check Linear labels for: `ops`, `maintenance`, `admin`, `devops`
   - Check title for keywords: "restore", "backup", "migrate", "configure", "setup", "fix", "investigate", "cleanup"
   - Check description length and complexity (short + clear scope -> specification)
   - Check description for procedural content (step-by-step instructions -> operational)

4. **Auto-classify if clear indicators**:
   - 2+ ops keywords -> likely operational
   - Short, well-scoped description with no architecture decisions needed -> likely specification
   - Complex feature requiring architecture decisions -> development

5. **Ask user if ambiguous**:
   ```
   TASK TYPE CLASSIFICATION

   Task: REC-XX - [title]
   Labels: [labels]
   Indicators found: [list]

   Which workflow should we use?

   1. [development] - Full workflow (design doc Q&A -> plan -> implement -> PR)
      Use for: New features with architecture decisions, complex cross-module changes (L scope)

   2. [specification] - Lean workflow (write spec -> implement -> PR)
      Use for: Well-scoped features, clear requirements, single-module changes (S/M scope)

   3. [operational] - Streamlined workflow (execute -> document -> PR if needed)
      Use for: Troubleshooting, configuration, admin tasks, investigations

   Your choice:
   ```

6. **Initialize based on classification**:

   **For Development tasks**:
   ```yaml
   task_type: development
   workflow:
     current_phase: discovery    # or "design" if --skip-discovery
     status: awaiting_input
   phases:
     discovery: { status: pending }   # or { status: skipped, skip_reason: "--skip-discovery flag" }
     design: { status: pending }
     plan: { status: pending }
     implement: { status: pending }
     pr: { status: pending }
     complete: { status: pending }
   ```

   If `--skip-discovery` flag is set:
   - Set `workflow.current_phase: design`
   - Set `phases.discovery.status: skipped`
   - Set `phases.discovery.skip_reason: "--skip-discovery flag"`
   - Set `phases.discovery.approved: true`

   **For Specification tasks**:
   ```yaml
   task_type: specification
   workflow:
     current_phase: spec
     status: awaiting_input
   phases:
     discovery: { status: skipped, skip_reason: "Specification task", approved: true }
     design: { status: skipped, reason: "Specification task - using /spec instead" }
     spec: { status: pending, spec_file: null, approved: false }
     implement: { status: pending }
     pr: { status: pending }
     complete: { status: pending }
   ```

   **For Operational tasks**:
   ```yaml
   task_type: operational
   workflow:
     current_phase: execute
     status: in_progress
   phases:
     discovery: { status: skipped, skip_reason: "Operational task", approved: true }
     design: { status: skipped, reason: "Operational task" }
     plan: { status: skipped, reason: "Operational task" }
     execute: { status: pending }
     document: { status: pending }
     pr: { status: pending, required: false }
     complete: { status: pending }
   ```

---

## Step 2.4: The File-Based Task Contract (File-Based Track Only)

The task file is the spec. Wire it in rather than reproducing it:

```yaml
task_id: R0-02
linear_url: null                    # valid; this track has no Linear issue
task_type: specification
phases:
  spec:
    status: complete                # the file IS the approved spec
    spec_file: docs/tasks/r0-02-delete-governance.md
    approved: true
    execution_mode: AFK             # AFK | HITL, from the task file's Type line
```

Consequences worth stating, because R0-01 improvised all of them:

- **Do not run the spec phase's authoring step.** It is already done. The spec
  phase's review step still applies if you want a second reader on the task
  file, but the file arrives pre-approved.
- **Acceptance criteria are the gate's Layer 1.** `scripts/gate.sh --task
  <task-id>` prints them; the implement phase runs them. They are not restated
  anywhere else, and they are not paraphrased.
- **`docs/tasks/README.md` holds the dependency ordering.** Check the task's
  `Blocked by:` line against the board before starting. A blocked task is a
  `blocked` workflow, not a slow one.
- **`skip_reason` prose is a smell.** Phases that this track legitimately skips
  are skipped by the shape above, once, in the template. Writing a paragraph
  explaining why a phase did not run means the shape is wrong - fix the shape.

---

## Step 2.5: Sync Project Aggregation Files (New Workflow Only)

**IMPORTANT**: This step only runs when starting a NEW workflow (not resuming).

1. **Invoke**: `/project:sync <task-id> --start`

2. **This validates** against `project.md`, the single board file:
   - The task's row exists
   - Its `Blocked by` column names no unfinished task

3. **If validation fails**:
   - `/project:sync` will display the issue and options
   - User must resolve before proceeding
   - Workflow enters `blocked` state until resolved

4. **If validation passes**:
   - `project.md`: the task's Status becomes `doing`
   - Add history entry: `project_sync_start`

---

## Return to Dispatcher

After initialization/resume completes, return control to the dispatcher with `current_phase` set. The dispatcher will load the appropriate phase file.
