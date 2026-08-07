# /task:orchestrate - Complete Task Lifecycle Management

**Purpose**: Orchestrate the complete lifecycle of a Linear task from design through PR merge. Manages workflow state, coordinates phase transitions, and ensures checkpoints for human validation.

**Usage**:
- `/task:orchestrate REC-XX` - Start or resume a task workflow
- `/task:orchestrate REC-XX --status` - Show current workflow state only
- `/task:orchestrate REC-XX --ops` - Start as operational task (skip design/plan)
- `/task:orchestrate REC-XX --spec` - Start as specification task (use /spec instead of full design doc)
- `/task:orchestrate REC-XX --skip-discovery` - Skip discovery phase (go straight to design)
- `/task:orchestrate` - Interactive mode

---

## State Machine

```
ENTRY -> DISCOVERY -> DESIGN -> PLAN -> IMPLEMENT -> PR -> COMPLETE  (development)
ENTRY -> SPEC -> IMPLEMENT -> PR -> COMPLETE                         (specification)
ENTRY -> EXECUTE -> DOCUMENT -> PR (conditional) -> COMPLETE         (operational)
                          |
                       BLOCKED (any phase)
```

**State file**: `docs/status/rec-XX-workflow.yaml`
**Phase instructions**: `.claude/commands/task/phases/{phase}.md`

---

## Dispatch Logic

1. **Parse arguments**: Read `phases/init.md` for initialization/resume logic
2. **Read workflow YAML** to determine `current_phase` and `status`
3. **Load the phase file** for the current phase and follow its instructions:

| Phase | File | Entry Condition |
|-------|------|-----------------|
| Initialize | `phases/init.md` | No workflow YAML exists |
| Discovery | `phases/discovery.md` | `current_phase: discovery` (development tasks) |
| Spec | `phases/spec.md` | `current_phase: spec` (specification tasks) |
| Design | `phases/design.md` | `current_phase: design` |
| Plan | `phases/plan.md` | `current_phase: plan` |
| Implement | `phases/implement.md` | `current_phase: implement` |
| PR | `phases/pr.md` | `current_phase: pr` |
| Complete | `phases/complete.md` | `current_phase: complete` |
| Blocked | `phases/blocked.md` | `status: blocked` (any phase) |
| Status | `phases/status.md` | `--status` flag |
| Operational | `phases/operational.md` | `task_type: operational` |

4. **After each phase completes**: the phase file MUST complete its YAML Checkpoint (see bottom of each phase file), THEN update `workflow.current_phase`. The orchestrator MUST validate the checkpoint before loading the next phase (Step 3.5).

---

## Phase Transition Validation (Step 3.5)

**CRITICAL**: Before loading the next phase file, validate the outgoing phase.

After a phase file signals completion by updating `workflow.current_phase`, re-read the YAML and verify the following minimum fields exist and are non-null:

### Required Fields per Phase

| Outgoing Phase | Required Fields (must be non-null/non-empty) |
|---|---|
| discovery | `discovery.status=complete` OR `discovery.status=skipped`, `discovery.approved=true` |
| spec | `spec.status=complete`, `spec.spec_file`, `spec.approved=true`, `spec.review_completed` |
| design | `design.status=complete`, `design.design_doc`, `design.draft_ready=true`, `design.finalized=true`, `design.review_completed` |
| plan | `plan.status=complete`, `plan.plan_file`, `plan.approved=true` |
| implement | `implement.status=complete` |
| pr | `pr.status=complete`, `pr.pr_url`, `pr.pr_number` |

**Advisor checkpoint (when `advisor.enabled`):** for outgoing `plan` and `spec`,
`advisor.calls[]` must contain a `checkpoint: A` entry for that phase (any verdict,
including `skipped` or `failed`). A skipped or failed consult still records a calls
entry, so it counts as "attempted" and never blocks the transition.

For outgoing `implement`, `advisor.calls[]` must likewise contain a `checkpoint: B`
entry (any verdict, including `skipped` or `failed`).

Also for outgoing `implement`, when `outcome.max_iterations > 0`, `outcome.status`
must be resolved (`satisfied`, `exhausted`, `waived`, or `ungraded` - not `pending`).

### If Validation Fails

1. **DO NOT** load the next phase file
2. Display: `TRANSITION BLOCKED: Phase [X] is missing required fields: [list]`
3. Fill the missing fields from available context:
   - History entries (timestamps, details)
   - File system (glob for design docs, plans, reviews)
   - Git log (commit SHAs)
   - GitHub CLI (`gh pr list/view` for PR data)
4. Re-validate - only proceed when all required fields are present

---

## Advisor Consult and Outcome Loop

An **advisor consult** runs at three checkpoints. It is a one-shot higher-tier
`Agent` subagent that reviews a phase artifact before cheaper executors commit;
it is a consult, never an approver, and is gated on `advisor.enabled`. The
checkpoints are: **A** in `plan` (and `spec` on that path) before the approval
gate; **B** in `implement` before the first write, and only when it adds signal
(a resumed session or `main` drift since approval); **C** inside the `validate`
loop, on FAIL, proposing the fix. Every verdict is recorded in `advisor.calls[]`
keyed by checkpoint. A consult that is skipped or fails is recorded and never
blocks a transition. The mechanics live in the phase files; orchestrate.md only
dispatches.

The `implement` phase Step 5 also runs a bounded **outcome loop** around the
**validation gate**. The gate has four layers: the task's acceptance criteria,
`cargo fmt/check/test`, a `yaml.safe_load` sweep, and model review.
`scripts/gate.sh` owns the middle two and exits `0`/`1`/`2` for
PASS/FAIL/INCOMPLETE. On FAIL the loop auto-dispatches a scoped fix and re-runs
the whole gate up to `outcome.max_iterations` (default 3, cap 5; `0` disables)
before the human menu.

Only an `INCOMPLETE` deterministic verdict - a binding layer that could not run -
resolves to `outcome.status: ungraded`. A missing model-review backend does not:
the first three layers still grade the work. Getting that distinction wrong is
what left R0-01 ungraded with every local check green. Both loop and advisor are
pattern-level adoptions of the Advisor tool and Managed Agents Outcomes - no API
calls. The mechanics live in `phases/implement.md`; orchestrate.md only
dispatches.

---

## State Persistence

**CRITICAL**: Update workflow state file after EVERY action.

```yaml
history:
  - timestamp: [ISO timestamp]
    action: [action name]
    phase: [current phase]
    details: [what happened]
```

### History Action Types

| Action | Description |
|--------|-------------|
| `workflow_started` | Initial workflow creation |
| `project_sync_start` | Task added to Active Work via `/project:sync --start` |
| `problem_framed` | Problem statement validated by user |
| `discovery_report_complete` | PRD discovery report produced |
| `discovery_pivot` | User changed direction based on discovery findings |
| `discovery_approved` | Discovery phase approved, proceeding to design |
| `task_skipped_after_discovery` | Discovery showed task should not be built |
| `design_started` | Design doc creation began |
| `design_draft_ready` | Design doc draft completed |
| `design_review_started` | AI review of design document began |
| `design_review_complete` | AI review completed with verdict |
| `design_review_timeout` | AI review timed out |
| `design_review_failed` | AI review encountered an error |
| `design_finalized` | Design doc approved and finalized |
| `spec_review_complete` | AI review of specification completed with verdict |
| `spec_review_failed` | AI review of specification failed or timed out |
| `spec_review_applied` | AI review feedback applied to specification |
| `spec_approved` | Specification approved for implementation |
| `plan_created` | Implementation plan generated |
| `plan_approved` | Plan approved for implementation |
| `phase_completed` | Implementation phase finished |
| `implementation_complete` | All plan tasks done |
| `commit_created` | Git commit made |
| `pushed_to_remote` | Branch pushed to origin |
| `pr_created` | Pull request created |
| `review_addressed` | PR review feedback addressed |
| `pr_approved` | PR approved for merge |
| `pr_merged` | PR merged to main |
| `project_sync_complete` | Task moved to Recently Completed via `/project:sync --complete` |
| `workflow_complete` | Full workflow finished |
| `workflow_paused` | User paused workflow |
| `workflow_resumed` | Workflow resumed from pause |
| `workflow_blocked` | Task blocked by another task |
| `workflow_unblocked` | Blocker resolved, task unblocked |
| `advisor_consult` | Advisor consult ran at a checkpoint (phase, checkpoint, verdict) |
| `advisor_skipped` | Trigger-scoped consult (B) did not fire (reason) |
| `advisor_failed` | Advisor consult timed out or errored; workflow proceeded |
| `outcome_iteration` | One grade-and-retry pass completed |
| `outcome_satisfied` | Outcome loop passed the gate (loop exit) |
| `outcome_exhausted` | Outcome loop hit max_iterations and escalated to human |
| `outcome_ungraded` | A required grader was unavailable; escalated to human |
| `waiver` | Human waived the whole gate with a recorded reason |
| `override` | Human proceeded past a FAIL at the Step 5 menu |

---

## Integration with Existing Skills

### Development Task Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| `/project:sync --start` | Entry | Validate WIP limit, add to Active Work |
| `/prd create` | Discovery | Draft lightweight PRD if none exists |
| `/prd-discovery` | Discovery | Multi-model PRD review, prior-art research, assumption mapping |
| `/design-doc:create` | Design | Interactive design creation (receives discovery report) |
| `/design-doc:review` | Design | AI review (Gemini + Ollama) |
| `/design-doc:finalize` | Design | Mark design as approved |
| `/plan:create` | Plan | Generate implementation plan |
| `/plan:implement` | Implement | Execute plan phases |
| `/pr:create` | PR | Create pull request |
| `/pr:review` | PR | Handle review feedback |
| `/pr:finalize` | Complete | Post-merge cleanup |
| `/project:sync --complete` | Complete | Move to Recently Completed, unblock dependents |
| `/project:sync --block` | Any (on block) | Update blockers in aggregation files |
| `/project:sync --unblock` | Any (on recovery) | Remove from blockers, mark ready |

### Specification Task Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| `/project:sync --start` | Entry | Validate WIP limit, add to Active Work |
| `/spec` | Spec | Write 5-section autonomous specification |
| Gemini + Ollama review | Spec | AI review of specification (parallel, same pattern as design review) |
| `/plan:implement` | Implement | Execute spec decomposition |
| `/pr:create` | PR | Create pull request |
| `/pr:review` | PR | Handle review feedback |
| `/pr:finalize` | Complete | Post-merge cleanup |
| `/project:sync --complete` | Complete | Move to Recently Completed |

### Operational Task Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| `/project:sync --start` | Entry | Validate WIP limit, add to Active Work |
| *(manual execution)* | Execute | Interactive procedure execution |
| *(status file updates)* | Document | Capture findings and lessons |
| `/pr:create` | PR (conditional) | Only if code changes |
| `/pr:finalize` | Complete | Post-merge cleanup (if PR created) |
| `/project:sync --complete` | Complete | Move to Recently Completed |

---

## Philosophy

**This orchestrator is designed to**:

1. **Provide single entry point**: One command for entire task lifecycle
2. **Enable resume capability**: Pick up where you left off
3. **Ensure human checkpoints**: Validate at critical decision points
4. **Maintain visibility**: Clear status at all times
5. **Coordinate skills**: Chain existing skills intelligently
6. **Track history**: Full audit trail of actions

**This orchestrator does NOT**:

1. **Make architectural decisions**: Uses design docs and plans
2. **Skip validation**: Requires human approval at checkpoints
3. **Force completion**: User can pause anytime
4. **Hide state**: Everything persisted in YAML file
