# Phase: Plan

**Purpose**: Generate an implementation plan from the design document and get user approval.

**Entry conditions**: `current_phase: plan`

---

## Status: pending or in_progress

1. **Check if plan exists**: `docs/plan/rec-XX-*.md`

2. **If plan does NOT exist**:
   - Display: "Creating implementation plan from design document."
   - Update state: `phases.plan.status: in_progress`
   - **Invoke**: `/plan:create REC-XX`
   - After completion, update state:
     - `phases.plan.plan_file: [path]`
     - `phases.plan.status: checkpoint`
     - `workflow.status: checkpoint`
   - Add history entry: `plan_created`

3. **If plan exists**:
   - Display: "Implementation plan already exists."
   - Update state: `phases.plan.status: checkpoint`

---

## Status: checkpoint

### Advisor Consult (Checkpoint A)

Run once before displaying the checkpoint, only if `advisor.enabled` is true and
`advisor.calls` has no `checkpoint: A` entry for this phase.

1. Resolve the advisor model: `advisor.model` if set, else the current session
   model (the floor). Resolve effort from `advisor.effort` (default `high`).
2. Dispatch a one-shot subagent with the `Agent` tool (`subagent_type: general-purpose`,
   `model:` = resolved advisor model). Give it ONLY this prompt (clean context, no
   session history):

   ```
   You are a strategic advisor reviewing an implementation approach BEFORE the
   executor commits. You are a consult, not an approver. Read only; change nothing.
   Read the design document at {phases.design.design_doc} and the draft plan at
   {phases.plan.plan_file}. Return a focused verdict, <= 80 words total, no full plan:
     verdict: proceed | revise | block
     reasons: up to 3 short bullets (only if revise or block)
   Judge whether the plan's approach is sound, matches the design's Acceptance
   Criteria, and has no obvious dead-end or risk. Default to proceed unless you see
   a concrete problem.
   ```
3. Append to `advisor.calls`:
   `{phase: plan, checkpoint: A, verdict: <verdict>, reasons: [<reasons>], ts: <ISO-8601 UTC>}`.
4. Add history entry `advisor_consult` (details: `checkpoint A: <verdict>`).
5. If the subagent errors or times out, append `{phase: plan, checkpoint: A,
   verdict: failed, reasons: [error], ts: <ISO-8601 UTC>}` to `advisor.calls`, add
   history entry `advisor_failed`, and proceed (a failed consult never blocks the
   checkpoint).

1. Display plan file location and summary
2. Ask user:
   ```
   PLAN CHECKPOINT

   Implementation plan: docs/plan/rec-XX-[description].md
   Total tasks: [X]
   Phases: [Y]
   Advisor (Checkpoint A): [proceed | revise | block]
   Advisor notes: [reasons, or "none"]

   Please review the implementation plan.

   Options:
   1. [approve] - Plan is approved, start implementation
   2. [regenerate] - Regenerate plan with different approach
   3. [pause] - Pause workflow, continue later

   Your choice:
   ```

3. **If approve**:
   - Update state:
     - `phases.plan.approved: true`
     - `phases.plan.main_sha_at_approval:` set to the output of `git rev-parse main`
     - `phases.plan.status: complete`
     - `workflow.current_phase: implement`
     - `workflow.status: in_progress`
   - Add history entry: `plan_approved`
   - **Continue to IMPLEMENT phase**

4. **If regenerate**:
   - Ask for guidance on different approach
   - Delete existing plan file
   - Re-invoke `/plan:create REC-XX` with updated guidance
   - Return to checkpoint

5. **If pause**:
   - Save state
   - Exit with resume instructions

---

## YAML Checkpoint (Required before transition)

Before signaling completion to the dispatcher, verify:
- `phases.plan.plan_file` is set (non-null)
- `phases.plan.approved: true`
- `phases.plan.status: complete`
- History contains `plan_created` and `plan_approved`
