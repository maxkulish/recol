# /pr:finalize - Post-Merge Cleanup and Task Completion

**Purpose**: Handle post-merge cleanup after a PR is merged. Updates aggregation files, Linear task status, and marks the task as complete. Supports both regular branches and git worktrees.

**Usage**:
- `/pr:finalize REC-XX` - Finalize specific task after merge
- `/pr:finalize` - Interactive mode

---

## When to Use

This command should be run:
1. After PR is merged to main
2. To complete the task lifecycle
3. To update project documentation

---

## Command Execution Instructions

### Step 1: Extract Task Number

1. **Get task number** from argument or detect from context
2. **If not provided**: Ask user or check workflow state

### Step 2: Detect Git Worktree Mode

Check if we're running in a git worktree:

```bash
# Check current directory name for worktree pattern (repo--branch)
basename "$PWD"

# List all worktrees to confirm
git worktree list
```

**Worktree Detection Logic**:
- If directory name matches pattern `*--*` (e.g., `recol--feat-rec-52-state-machine`), we're in a worktree
- Extract main repo name: everything before `--` (e.g., `recol`)
- Main repo path: `../<main-repo-name>` (e.g., `../recol`)

**Set variables for later steps**:
```bash
# Example for worktree: recol--feat-rec-52-state-machine
CURRENT_DIR=$(basename "$PWD")
if [[ "$CURRENT_DIR" == *"--"* ]]; then
    IS_WORKTREE=true
    MAIN_REPO_NAME="${CURRENT_DIR%%--*}"
    MAIN_REPO_PATH="../$MAIN_REPO_NAME"
else
    IS_WORKTREE=false
    MAIN_REPO_PATH="."
fi
```

Display:
```
Git Mode: [Worktree / Regular Branch]
Main Repo: [path]
Current Branch: [branch name]
```

### Step 3: Verify PR is Merged

```bash
gh pr list --head "feat/rec-XX-description" --json number,state,mergedAt
```

**If PR not merged**:
```
PR #[number] is not yet merged.

State: [Open/Closed]

Options:
1. [merge] - Merge the PR now
2. [wait] - Exit and wait for merge
3. [force] - Continue anyway (cleanup without merge)

Your choice:
```

**If PR is merged**: Continue

### Step 4: Prepare Main Repository for Updates

#### If Worktree Mode:

```bash
# Go to main repo folder
cd "$MAIN_REPO_PATH"

# Verify we're on main branch
git rev-parse --abbrev-ref HEAD  # Should be "main"

# Pull latest (includes merged PR)
git pull origin main
```

Display:
```
Working in main repo: [path]
Pulled latest changes including merged PR.
```

**IMPORTANT**: All subsequent file operations (Steps 6-9) happen in the main repo folder.

#### If Regular Branch Mode:

```bash
# Switch to main branch
git checkout main

# Pull latest changes
git pull origin main
```

Display:
```
Switched to main branch.
Pulled latest changes including merged PR.
```

### Step 5: Update Linear Task Status

```
mcp__linear-server__save_issue(
  id="REC-XX",
  state="Done"
)
```

Post final comment:

```
mcp__linear-server__save_comment(
  issueId="REC-XX",
  body="## Task Complete

**Status**: Done
**PR**: #[number] (merged)
**Merged At**: [timestamp]

**Summary**:
[Brief summary of what was implemented]

**Documents**:
- Design: `docs/designs/rec-XX-[description].md`
- Plan: `docs/plan/rec-XX-[description].md`
- Status: `docs/status/rec-XX-[description].md`

This task is now complete."
)
```

### Step 6: Update the Board

**IMPORTANT**: In worktree mode, all file paths are relative to the main repo folder (set in Step 4).

Do not edit the board by hand here. Run:

```bash
/project:sync <task-id> --complete "[one-line summary]"
```

That command owns `project.md`: which cell moves, what evidence the `## Done`
row needs, which rows the completion unblocks, and whether the `## Next` prose
and the dependency graph still hold. Earlier versions of this step edited
`PROJECT.md`, `ROADMAP.md` and `DEPENDENCIES.md` directly - three files that do
not exist in this repository - and every run had to work around their absence.
Duplicating the logic here is what let the two drift.

### Step 7: Commit the Board Update

**IMPORTANT**: Ensure you're in the main repo folder before committing.

```bash
# In worktree mode you are already in the main repo from Step 4
pwd

git add project.md docs/status/
git commit -m "docs(<task-id>): mark complete on the board"
git push origin main
```

### Step 8: Update Status File

**In worktree mode**: These files are in the main repo folder.

Update `docs/status/rec-XX-[description].md`:

```markdown
**Last Updated**: [Current Date/Time]

## Current Status: Complete

**Overall Progress**: 100% (X/X tasks)
**Completed**: [Date/Time]
**PR Merged**: [Date/Time]

---

## Final Summary

**Implementation**: Successfully completed all tasks.

**Modules**:
- [List of modules created/modified]

**Total Commits**: [count]
**PR**: #[number] (merged)
```

### Step 9: Update Workflow State (if exists)

**In worktree mode**: This file is in the main repo folder.

Update `docs/status/rec-XX-workflow.yaml`:

```yaml
workflow:
  current_phase: complete
  status: complete

phases:
  complete:
    status: complete
    board_updated: true
    merged_at: [ISO timestamp]

history:
  - timestamp: [ISO timestamp]
    action: workflow_complete
    phase: complete
    details: "Task REC-XX fully completed"
```

#### Commit Status File Updates (Worktree Mode)

If status files were updated in Steps 8-9, commit them:

```bash
# Still in main repo folder
git add docs/status/
git commit -m "$(cat <<'EOF'
docs(REC-XX): update status files for completed task

- Updated status file with final summary
- Marked workflow as complete
EOF
)"
git push origin main
```

**Alternative**: Include status files in the Step 7 commit by running Steps 6, 8, 9 before Step 7's commit.

### Step 10: Display Completion Summary

Render the canonical summary defined in `.claude/templates/completion-summary.md`.

- Load `docs/status/rec-XX-workflow.yaml`.
- Resolve every placeholder using the field-mapping table in the template (`Source of Data` section).
- Apply the phase-skip rules for the current `task_type`.
- Print the rendered block exactly as specified — preserve box-drawing characters, indentation, emojis, and separator widths.

The footer line `Status: ✅ DONE` is the single authoritative completion signal — emit it only when `workflow.current_phase == complete` AND `workflow.status == complete`.

#### Worktree Mode addendum

After the canonical summary, append exactly this block on a new line (only in worktree mode):

```
NEXT STEPS:
1. Exit Claude Code
2. Run `gd` to delete this worktree and branch
3. You'll be returned to the main repo folder
```

In regular branch mode, do not append anything after the canonical summary.

---

## Special Cases

### Case 1: The task has no row on the board

`/project:sync` stops and asks where the row belongs rather than guessing a
position. Answer it; do not skip the sync to keep moving. A completed task
missing from `project.md` is how the board stops being trustworthy.

### Case 2: Merge conflicts in `project.md`

```
WARNING: project.md has conflicts after git pull

Options:
1. [manual] - Exit and resolve manually (recommended - this file is prose)
2. [resolve] - Attempt auto-resolve
3. [skip] - Skip the board update
```

Prefer `manual`. `project.md` carries prose arguments in `## Next` and a
dependency graph that a textual merge will happily corrupt into something that
still parses.

### Case 3: Worktree Main Repo Not Found

```
WARNING: Main repo folder not found

Current directory: recol--feat-rec-52-state-machine
Expected main repo: ../recol

Options:
1. [path] - Specify main repo path manually
2. [skip] - Skip the board update (do it manually later)
3. [cancel] - Cancel finalization

Your choice:
```

### Case 4: Worktree Main Repo Has Uncommitted Changes

```
WARNING: Main repo has uncommitted changes

Changes in ../recol:
- project.md (modified)
- src/main.rs (modified)

Options:
1. [stash] - Stash changes, proceed, then unstash
2. [skip] - Skip aggregation updates
3. [cancel] - Cancel and resolve manually

Your choice:
```

---

## Cleanup Checklist

Before marking complete, verify:

- [ ] PR is merged to main
- [ ] Main branch is up-to-date locally (pulled in main repo)
- [ ] Linear task status is "Done"
- [ ] `project.md` updated via `/project:sync --complete`
- [ ] Status file has final summary
- [ ] Board update committed and pushed to main

**If Worktree Mode** (user handles after exiting):
- [ ] User runs `gd` to delete worktree and branch

---

## Integration Notes

**Called by**: `/task:orchestrate` as final step

**Follows**: PR merge

**Final step in workflow chain**

**Supports**:
- Regular branches (switches to main, optional branch deletion)
- Git worktrees (updates main repo folder, user runs `gd` to cleanup)

**Updates**:
- Aggregation files (all three, committed to main)
- Status file
- Workflow state file
- Linear task (Done status)

**Branch Cleanup**:
- **Regular mode**: Optional branch deletion offered
- **Worktree mode**: User runs `gd` after exiting Claude to delete worktree and branch
