# /design-doc:finalize - Finalize Design Documents

**Purpose**: Mark a design document as finalized after user approval. Updates the document status, posts to Linear, and prepares for implementation.

**Usage**:
- `/design-doc:finalize REC-XX` - Finalize specific design document
- `/design-doc:finalize` - Interactive mode

---

## When to Use

This command is typically invoked:
1. After `/design-doc:create` produces a draft
2. After user reviews and approves the design
3. Before `/plan:create` generates implementation plan

---

## Command Execution Instructions

### Step 1: Extract Task Number

1. **If user provided task number** (e.g., `/design-doc:finalize rec-9`):
   - Normalize to both formats (REC-9 for Linear, rec-9 for files)
   - Proceed to Step 2

2. **If no task number provided**:
   - Ask: "Which design document do you want to finalize? (e.g., REC-9)"
   - Wait for response

### Step 2: Locate Design Document

Search for design document:
```bash
ls docs/designs/rec-XX-*.md
```

**If NOT found**:
```
ERROR: Design document not found

Expected: docs/designs/rec-XX-*.md

Create one first: /design-doc:create REC-XX
```
Exit command.

**If found**: Read the document

### Step 3: Check Current Status

Read the design document header:

```markdown
**Status**: Draft | Finalized
```

**If already finalized**:
```
Design document is already finalized.

File: docs/designs/rec-XX-[description].md
Finalized: [date]

No action needed.
```
Exit command.

### Step 4: Validate Design Document

Check that required sections are complete:

| Section | Required | Check |
|---------|----------|-------|
| Summary | Yes | Not empty |
| Background | Yes | Not empty |
| Architecture | Yes | Not empty |
| Detailed Design | Yes | Contains implementation approach |
| Implementation Plan | Yes | Has at least one phase |
| Acceptance Criteria | Yes | Has at least 3 criteria |
| Open Questions | No | Check if empty |

**If Open Questions section has items**:
```
WARNING: Open questions exist

The following questions are still unresolved:
- [Question 1]
- [Question 2]

Options:
1. [finalize] - Finalize anyway (questions will be addressed during implementation)
2. [resolve] - Address questions first
3. [cancel] - Cancel finalization

Your choice:
```

### Step 5: Update Design Document

Edit the design document to update status:

**Change**:
```markdown
**Status**: Draft
```

**To**:
```markdown
**Status**: Finalized
**Finalized**: [Current Date]
**Approved By**: [User or "Team"]
```

### Step 6: Post to Linear

Create a comment on the Linear task:

```
mcp__linear-server__save_comment(
  issueId="REC-XX",
  body="## Design Document Finalized

The design document for this task has been reviewed and approved.

**Document**: `docs/designs/rec-XX-[description].md`
**Status**: Finalized
**Date**: [Current Date]

**Key Decisions**:
- [Summary of architectural decisions from the doc]

**Next Steps**:
1. Generate implementation plan: `/plan:create REC-XX`
2. Begin implementation: `/plan:implement REC-XX`

The design is now locked and ready for implementation."
)
```

### Step 7: Update Workflow State (if exists)

If `docs/status/rec-XX-workflow.yaml` exists, update it:

```yaml
phases:
  design:
    status: complete
    finalized: true

history:
  - timestamp: [ISO timestamp]
    action: design_finalized
    phase: design
    details: "Design document approved and finalized"
```

### Step 8: Git Commit

Commit the finalized design document and AI review (if exists):

The review files are whichever ones the Step 6 backend produced - `-gemini`,
`-ollama`, and `-claude-fallback` from lok, or `-architecture` and `-risk` from
the native fan-out - plus the synthesis. Glob for them rather than naming one:
an earlier version added `rec-XX-design-review.md`, a filename
`/design-doc:review` has never written, so reviews were silently left out of
every finalize commit.

```bash
# Add design document
git add docs/designs/rec-XX-[description].md

# Add every review this task produced, whichever backend wrote them
git add docs/reviews/rec-XX-review-*.md 2>/dev/null || true

git commit -m "$(cat <<'EOF'
docs(REC-XX): finalize design document

- Status updated from Draft to Finalized
- AI review included (if generated)
- Ready for implementation planning

Related: docs/designs/rec-XX-[description].md
EOF
)"
```

### Step 9: Confirm to User

```
SUCCESS: Design document finalized!

File: docs/designs/rec-XX-[description].md
Status: Finalized
Linear: Comment posted

The design is now approved and locked.

Next steps:
1. Generate plan: /plan:create REC-XX
2. Implement: /plan:implement REC-XX

Or continue with orchestrator: /task:orchestrate REC-XX
```

---

## Special Cases

### Case 1: Design document has errors

If validation finds issues:

```
VALIDATION FAILED: Design document incomplete

Missing or empty sections:
- [ ] Detailed Design (no implementation approach)
- [ ] Acceptance Criteria (less than 3 items)

Please complete these sections before finalizing.

Options:
1. [edit] - Open document for editing (exit command)
2. [force] - Force finalization (NOT recommended)
3. [cancel] - Cancel

Your choice:
```

### Case 2: Not on feature branch

```
WARNING: Not on feature branch

Current branch: main
Expected: feat/rec-XX-*

Commits to finalized docs should be on a feature branch.

Options:
1. [create] - Create feature branch
2. [continue] - Continue on main (NOT recommended)
3. [cancel] - Cancel

Your choice:
```

---

## Validation Checklist

Before finalizing, verify:

- [ ] Summary clearly describes the task objective
- [ ] Background provides context from Linear and architecture
- [ ] Architecture section includes component overview
- [ ] Detailed Design has implementation approach
- [ ] Implementation Plan has clear phases
- [ ] Acceptance Criteria are specific and testable
- [ ] Security Considerations addressed
- [ ] No critical Open Questions remain

---

## Document Status Lifecycle

```
Draft (created by /design-doc:create)
  │
  ▼
[User Review]
  │
  ▼
Finalized (by /design-doc:finalize)
  │
  ▼
[Implementation begins]
```

Once finalized:
- Document is considered "locked"
- Major changes require creating a new version
- Minor clarifications can be added inline

---

## Integration Notes

**Called by**: `/task:orchestrate` after design checkpoint approval

**Calls**: None (terminal action for design phase)

**Updates**:
- Design document (`docs/designs/rec-XX-*.md`)
- Workflow state file (if exists)
- Linear task (comment)
- Git repository (commit includes design doc and AI review if exists)
