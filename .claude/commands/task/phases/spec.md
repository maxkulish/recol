# Phase: Specification (Specification Tasks Only)

**Purpose**: Run the `/spec` skill to produce a lean 5-section specification, run AI review with whichever backend is reachable, apply feedback, and checkpoint for approval or upgrade to full design-doc workflow.

**Entry conditions**: `current_phase: spec` (task_type: specification)

---

## Status: pending or awaiting_input

1. **Invoke**: `/spec [task title and description from Linear]`
   - Pass the full Linear task title + description as context
   - The spec skill will explore the codebase, ask clarifying questions, and produce a 5-section specification
   - After completion, update state:
     - `phases.spec.spec_file: specs/[date]-rec-XX-[slug].md` (or wherever spec was saved)
     - `phases.spec.status: reviewing`
     - `workflow.status: in_progress`

---

## Status: reviewing

### Step 2: AI Review of Specification

Before presenting the spec to the user for approval, run the same two-reviewer
pattern the design phase uses, adapted for spec documents.

**2a. Gather context for reviewers**

Build a context block that gives reviewers the problem framing they need:

- **Linear task**: Fetch via `mcp__linear-server__get_issue` (title, description, labels, comments)
- **Spec file**: The spec produced in Step 1
- **Architecture context**: `docs/adr/` (relevant subset), `AGENTS.md`

**2b. Pick a review backend**

Use the first one that is actually present. Review degrades in quality here, not
to nothing: a spec that no second reader ever saw is the failure this step
exists to prevent.

**Backend 1 - lok**, if `.lok/workflows/spec-review.toml` exists in this repo.
The prompt lives in `.lok/prompts/spec-review-prompt.md`; no inline prompt
needed.

```bash
lok run .lok/workflows/spec-review.toml \
  "[SPEC_FILE_PATH]" \
  "[TASK_ID]" \
  "[TASK_TITLE]" \
  "[TASK_DESCRIPTION]" \
  "[TASK_LABELS]" \
  --dir . \
  --verbose
```

It writes `docs/reviews/<task-id>-spec-review-{gemini,ollama,synthesis}.md`.
Set `phases.spec.review_backend: lok`.

**Backend 2 - native fan-out**, otherwise. Dispatch two reviewer subagents with
the `Agent` tool (`subagent_type: general-purpose`) in a single message so they
run concurrently. Give each the spec file, the context block from 2a, and one
lens:

- *Testability*: is every Acceptance Criterion specific and measurable, and
  could someone who has not read this conversation verify it?
- *Completeness*: what does the Problem Statement leave undefined, and which
  constraint or edge case would bite during implementation?

Each returns a review ending in a verdict line of
`APPROVE | APPROVE_WITH_SUGGESTIONS | NEEDS_REVISION`. Write them to
`docs/reviews/<task-id>-spec-review-<lens>.md`, then write a synthesis to
`docs/reviews/<task-id>-spec-review-synthesis.md` taking the strictest verdict
and merging the actionable feedback. Set `phases.spec.review_backend: native`.

**Backend 3 - none**: no reviewer was reachable. Set
`phases.spec.review_backend: none`, `phases.spec.review_completed: false`, and
say so at the checkpoint. Do not silently present an unreviewed spec as
reviewed.

**2c. Check review results**

Read the synthesis file.

- If it contains `NO_REVIEWS_AVAILABLE`: every reviewer failed. Treat as
  backend `none` and proceed to step 2e (checkpoint).
- If one review file contains `REVIEW_FAILED`: note which and proceed with the
  available review.
- Otherwise: proceed with full synthesis.

Update workflow state:
- `phases.spec.review_backend: [lok | native | none]`
- `phases.spec.review_reports: [<paths of the individual reviews>]`
- `phases.spec.review_synthesis: docs/reviews/<task-id>-spec-review-synthesis.md`
- `phases.spec.review_completed: [true | false]`

**2e. Apply review feedback**

Follow the same pattern as design phase feedback application:

1. **Extract actionable items** from both reviews' "Actionable Feedback" sections
2. **Classify each item**:

| Classification | Criteria | Action |
|---------------|----------|--------|
| **Additive** | Missing acceptance criterion, edge case, or test scenario | AUTO-APPLY to spec |
| **Refinement** | Improves clarity, specificity, or scoping of existing items | AUTO-APPLY to spec |
| **Contradicts prior decision** | Recommends approach rejected in ADRs | ASK USER |
| **New risk identified** | Blind spot not covered | AUTO-APPLY (add to constraints or evaluation) |
| **Ambiguous** | Cannot be clearly classified | AUTO-APPLY with `<!-- reviewer note -->` comment |

3. **Apply non-contradicting items** in a single edit pass to the spec file
4. **Handle contradicting items** one at a time (same UI as design phase):
   ```
   REVIEW CONFLICT - Item [N of M]

   Suggestion (from [reviewer name, or "both"]):
     "[exact suggestion text]"

   This conflicts with a prior decision:
     Source: [docs/adr/adr-XXX.md]
     Decision: "[relevant excerpt]"

   Options:
     1. [skip]  - Keep our prior decision
     2. [apply] - Override and apply
     3. [note]  - Add as open question

   Your choice:
   ```

5. Update state:
   - `phases.spec.review_applied: true`
   - `phases.spec.applied_suggestions: [list]`
   - `phases.spec.flagged_suggestions: [list]` (if any contradictions)
- Add history entry: `spec_review_applied`

Update state: `phases.spec.status: checkpoint`, `workflow.status: checkpoint`

---

## Status: checkpoint

### Advisor Consult (Checkpoint A)

Run once before displaying the checkpoint, only if `advisor.enabled` is true and
`advisor.calls` has no `checkpoint: A` entry for the `spec` phase.

1. Resolve the advisor model: `advisor.model` if set, else the current session
   model (the floor). Resolve effort from `advisor.effort` (default `high`).
2. Dispatch a one-shot subagent with the `Agent` tool (`subagent_type: general-purpose`,
   `model:` = resolved advisor model). Give it ONLY this prompt (clean context, no
   session history):

   ```
   You are a strategic advisor reviewing an implementation approach BEFORE the
   executor commits. You are a consult, not an approver. Read only; change nothing.
   Read the spec file at {phases.spec.spec_file}. Return a focused verdict, <= 80
   words total, no full plan:
     verdict: proceed | revise | block
     reasons: up to 3 short bullets (only if revise or block)
   Judge whether the spec's approach is sound, its Acceptance Criteria are
   specific and testable, and there is no obvious dead-end or risk. Default to
   proceed unless you see a concrete problem.
   ```
3. Append to `advisor.calls`:
   `{phase: spec, checkpoint: A, verdict: <verdict>, reasons: [<reasons>], ts: <ISO-8601 UTC>}`.
4. Add history entry `advisor_consult` (details: `checkpoint A: <verdict>`).
5. If the subagent errors or times out, append `{phase: spec, checkpoint: A,
   verdict: failed, reasons: [error], ts: <ISO-8601 UTC>}` to `advisor.calls`, add
   history entry `advisor_failed`, and proceed (a failed consult never blocks the
   checkpoint).

1. Display spec file location and review results
2. Ask user:
   ```
   SPEC CHECKPOINT

   Specification: [spec file path]
   Scope: [S/M/L from spec header]
   Sub-tasks: [count from spec decomposition]
   Advisor (Checkpoint A): [proceed | revise | block]
   Advisor notes: [reasons, or "none"]

   ---
   AI REVIEW RESULTS ([lok | native | none])

   [reviewer 1]:  [APPROVE | APPROVE_WITH_SUGGESTIONS | NEEDS_REVISION]
   [reviewer 2]:  [APPROVE | APPROVE_WITH_SUGGESTIONS | NEEDS_REVISION]
   Consensus:     [strictest of both]

   Auto-applied [N] suggestions:
   - [brief description of each applied change]

   User-resolved [M] conflicts:
   - [suggestion] -> [skip|apply|note]

   (If reviews failed: "AI review unavailable - spec unchanged from draft")
   ---

   Please review the spec - all 5 sections should be complete:
   - Problem Statement (self-contained?)
   - Acceptance Criteria (specific + measurable?)
   - Constraints (Must/Must-not/Prefer/Escalate?)
   - Decomposition (independent sub-tasks?)
   - Evaluation (test table complete?)

   Options:
   1. [approve]  - Spec is approved, start implementation directly
   2. [revise]   - I have feedback (will re-invoke /spec)
   3. [view]     - View a full review (lists `phases.spec.review_reports`)
   4. [upgrade]  - This is more complex than expected, switch to full design-doc workflow
   5. [pause]    - Pause workflow, continue later

   Your choice:
   ```

3. **If approve**:
   - Update state:
     - `phases.spec.approved: true`
     - `phases.spec.main_sha_at_approval:` set to the output of `git rev-parse main`
     - `phases.spec.status: complete`
     - `workflow.current_phase: implement`
     - `workflow.status: in_progress`
   - Add history entry: `spec_approved`
   - **Continue to IMPLEMENT phase** (skip PLAN phase - spec decomposition IS the plan)

4. **If revise**:
   - Ask for specific feedback
   - Re-invoke `/spec` with feedback context
   - Re-run AI review (return to `status: reviewing`)
   - Return to checkpoint

5. **If view**: List `phases.spec.review_reports`, display the one chosen, return to options

6. **If upgrade**:
   - Update state: `task_type: development`
   - Reinitialize phases with design + plan
   - **Continue to DESIGN phase**

7. **If pause**:
   - Save state
   - Exit with resume instructions

---

## YAML Checkpoint (Required before transition)

Before signaling completion to the dispatcher, verify:

```yaml
# --- Spec phase exit fields ---
phases.spec.spec_file: <path>                    # non-null
phases.spec.approved: true
phases.spec.status: complete
phases.spec.review_backend: <lok|native|none>    # which backend actually ran
phases.spec.review_reports: [<paths>]            # empty array if no reviewer answered
phases.spec.review_synthesis: <path|null>        # null if no reviewer answered
phases.spec.review_verdict: <verdict|null>       # null if review failed/timed out
phases.spec.review_completed: <true|false>       # false if reviews failed/timed out
phases.spec.review_applied: <true|false>         # false if no reviews or nothing to apply
phases.spec.applied_suggestions: [<list>]        # empty array if none applied
phases.spec.flagged_suggestions: [<list>]        # empty array if no conflicts
```

History must contain `spec_approved` event.
