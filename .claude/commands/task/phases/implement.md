# Phase: Implement

**Purpose**: Execute the implementation plan phase by phase, tracking commits and pushing to remote. Run external model validation before transitioning to PR.

**Entry conditions**: `current_phase: implement`

---

## Status: pending or in_progress

### Advisor Consult (Checkpoint B, trigger-scoped)

Run once before the first write, only if `advisor.enabled` is true and
`advisor.calls` has no `checkpoint: B` entry yet.

1. Decide whether B fires. It fires only when it adds signal:
   - **Resume:** a `workflow_resumed` history entry exists dated after the
     `plan_approved` (or `spec_approved`) entry, OR
   - **Drift:** `git rev-parse main` differs from `phases.plan.main_sha_at_approval`
     (use `phases.spec.main_sha_at_approval` on the spec path).
2. **If neither trigger holds:** append `{phase: implement, checkpoint: B,
   verdict: skipped, reasons: [], ts: <ISO-8601 UTC>}` to `advisor.calls`, add a
   history entry `advisor_skipped` (details: `checkpoint B: no-drift`), and continue
   to step `1` below. Do not dispatch a subagent.
3. **If a trigger holds:** dispatch a one-shot `Agent` subagent
   (`subagent_type: general-purpose`, `model:` = resolved advisor model, effort from
   `advisor.effort`) with ONLY this prompt:

   ```
   You are a strategic advisor. The plan for this task was approved earlier; since
   then {trigger: the session resumed / main advanced}. Read only; change nothing.
   Read the plan at {phases.plan.plan_file} (or the spec at {phases.spec.spec_file})
   and run `git log --oneline {main_sha_at_approval}..main` to see what changed on
   main. Return <= 80 words:
     verdict: proceed | revise | block
     reasons: up to 3 short bullets (only if revise or block)
   Judge whether the approved approach still holds given what changed. Default to
   proceed unless the drift concretely invalidates the plan.
   ```

   Append `{phase: implement, checkpoint: B, verdict: <verdict>, reasons: [...],
   ts: ...}` to `advisor.calls`; add history entry `advisor_consult` (details:
   `checkpoint B: <verdict>`). On subagent error/timeout append `{phase: implement,
   checkpoint: B, verdict: failed, reasons: [error], ts: ...}` to `advisor.calls`, add
   history `advisor_failed`, and proceed.
4. **Landing for a `block` verdict:** there is no human gate after B, so set
   `workflow.status: checkpoint`, display a one-line notice
   `ADVISOR BLOCK (Checkpoint B): <reasons>` and ask the user to `[proceed]` or
   `[pause]` before the first write. `proceed` continues; `pause` saves state and exits.

1. Update state: `phases.implement.status: in_progress`
2. **Invoke**: `/plan:implement REC-XX`

3. After each phase completion within `/plan:implement`:
   - Update workflow state:
     - `phases.implement.last_phase_completed: [phase name]`
     - Add commit SHA to `phases.implement.commits[]`
   - **Push to remote**:
     ```bash
     git push origin feat/rec-XX-short-desc
     ```
   - Add history entry: `phase_completed` with details of phase name
   - Add history entry: `pushed_to_remote`

4. When `/plan:implement` reaches 100%:
   - Add history entry: `implementation_complete`
   - **Continue to Validation Gate** (Step 5)

### Scope discipline while implementing

A defect you notice on the way that belongs to another task gets flagged and
deferred, not fixed: leave a `// TODO(r0): ...` marker if the code would
otherwise mislead, append `{path, reason, owner_task}` to
`phases.implement.deliberately_not_changed`, and say it in the PR description.
Fix it inline only when the task cannot pass its own acceptance criteria
without the fix.

Widening the diff destroys the property the task was cut for: that the change
and the acceptance criteria describe the same thing. See conventions W1.

---

## Step 5: Validation Gate

**After implementation is complete, before creating a PR.** The gate is this
phase's referee. It has four layers, cheapest and most certain first:

| Layer | What | Binding? |
|---|---|---|
| L1 | The task's own acceptance criteria | yes |
| L2 | `cargo fmt` / `check` / `test` | yes |
| L3 | `yaml.safe_load` over the YAML we author | yes |
| L4 | Model review | only when it ran |

L1-L3 are deterministic and always available. L4 is model judgment and is
**allowed to be absent**: a repo with no reviewer backend still has a gate.
This is the one rule that matters, because getting it wrong is what left R0-01
`ungraded` with every local check green.

Run the layers in order. The runner does not stop at the first failure - it
reports every layer, so one FAIL cannot hide another - but a FAIL anywhere stops
the phase.

### Layers 1-3: the deterministic runner

`scripts/gate.sh` owns L2 and L3 and lists L1, whose criteria you run yourself.

```bash
scripts/gate.sh --task <task-id>          # full tier, at the end of implement
scripts/gate.sh --task <task-id> --quick  # per-task tier, defers cargo test
```

Exit codes: `0` PASS, `1` FAIL, `2` INCOMPLETE (a layer could not run, which is
never a pass).

**L1 is yours to run.** The runner prints the task file's acceptance criteria
but cannot execute them: their expected results are stated in prose ("returns
nothing", "fails for every path"), which is what makes them good criteria and
bad shell. Run each one verbatim and record the result. A criterion nobody can
run is a bug in the task file, not a criterion to waive.

Copy the runner's `GATE SUMMARY` lines into `gate.layers` and set
`gate.deterministic_verdict` to its verdict. Add history entry `gate_run`
(details: tier and verdict), or `gate_incomplete` on exit 2.

### Layer 4: model review (optional)

Pick the first backend that is actually present:

1. **lok**, if `.lok/workflows/implement-gate.toml` exists in this repo:

   ```bash
   # arg.1 = task ID (lowercase),  arg.2 = branch name
   lok workflow run implement-gate <task-id> <branch>
   ```

   The workflow owns prompt assembly, parallel reviewer dispatch, output
   validation, the Claude fallback, and the synthesis write. Overrides:
   `CODEX_MODEL` (default `gpt-5.6-sol`), `GEMINI_MODEL` (default
   `gemini-3.1-pro-preview`), `GEMINI_FALLBACK_MODEL` (default
   `gemini-3.6-flash`). Gemini is reached through
   `opencode run --model "google/$MODEL" --agent plan`; the standalone `gemini`
   CLI is deprecated and must not be called from this phase. Set
   `gate.llm_layer: lok`.

2. **Native fan-out**, otherwise. Dispatch two reviewer subagents with the
   `Agent` tool (`subagent_type: general-purpose`) in a single message so they
   run concurrently. Give each one only the diff (`git diff main...HEAD`), the
   task file, and one lens:

   - *Correctness*: does this change do what the task says, and what does it
     break that the tests do not cover?
   - *Contract*: does the diff stay inside the task's Scope, and does every
     acceptance criterion actually hold against this code?

   Then dispatch a third subagent to adjudicate: it reads both reviews, drops
   findings neither can substantiate against the diff, and writes
   `docs/reviews/<task-id>-validation-synthesis.md` ending in a `## Verdict`
   line of `approve | approve_with_changes | pivot | rework`. Two reviewers and
   an adjudicator, not one reviewer: a single model grading its own family of
   output is the failure mode this layer exists to avoid. Set
   `gate.llm_layer: native`.

3. **Neither reachable**: set `gate.llm_layer: none`, record why, and grade on
   L1-L3. Do not set `outcome.status: ungraded` - the gate ran.

Record every report path in `phases.implement.validation_reports`.

Anti-pattern (do not do this): shelling out to `codex exec` or `gemini`
directly, or hand-writing a review file to make the step pass. That bypasses
output validation and synthesis, and it manufactures the appearance of a
referee where there is none. If no backend is reachable, say so in
`gate.llm_layer` and let L1-L3 do the grading.

### Display Results

```
VALIDATION GATE (<task-id>)
===========================

L1 acceptance   [PASS | FAIL]  [n/m criteria met]
L2 fmt/check/test  [PASS | FAIL | DEFERRED]
L3 yaml         [PASS | FAIL]
Deterministic verdict: [PASS | FAIL | INCOMPLETE]

L4 model review ([lok | native | none]):
  Verdict: [approve | approve_with_changes | pivot | rework | not run]
  Report:  [docs/reviews/<task-id>-validation-synthesis.md | -]
  Key findings: [top 3, or "none"]

Options:
1. [proceed]  - Continue to PR creation
2. [fix]      - Address findings before PR (recommended if FAIL)
3. [override] - Skip validation and proceed (not recommended)
4. [pause]    - Pause workflow

Your choice:
```

### Outcome Loop (grade-and-retry, Checkpoint C)

Combine the deterministic verdict with L4 into one loop state. The
deterministic layers outrank the model: they cannot be argued with.

| L1-L3 | L4 verdict | Loop state |
|---|---|---|
| FAIL | any | FAIL |
| INCOMPLETE | any | `ungraded` - a binding layer did not run |
| PASS | not run (`llm_layer: none`) | PASS |
| PASS | `approve` | PASS |
| PASS | `approve_with_changes` | PASS_WITH_NOTES |
| PASS | `pivot`, `rework` | FAIL |

When L4 ran, its binding verdict is the `## Verdict` line at the end of
`docs/reviews/<task-id>-validation-synthesis.md`. Do not re-derive it by
combining the raw reviewer reports: they are inputs to synthesis, not graders in
their own right.

Then, if `outcome.max_iterations` is `0`, skip the loop and go straight to
the human menu below (Step-5 behaves as it did before this feature).

Otherwise run:

1. **Grader unavailable.** This means `gate.deterministic_verdict` is
   `INCOMPLETE` - `scripts/gate.sh` exited 2 because a binding layer could not
   run. Set `outcome.status: ungraded`, add history `outcome_ungraded`, and go
   to the human menu. Do not iterate without a grader.

   A missing L4 is **not** this case. If L1-L3 produced PASS or FAIL, the gate
   graded the work and the loop proceeds normally.
2. **Combined verdict PASS or PASS_WITH_NOTES:** set `outcome.status: satisfied`,
   add history `outcome_satisfied`, and continue to `### Transition to PR`.
3. **Combined verdict FAIL:**
   a. `outcome.iteration += 1`; add history `outcome_iteration`.
   b. If `outcome.iteration >= outcome.max_iterations` (cap 5): set
      `outcome.status: exhausted`, add history `outcome_exhausted`, and go to the
      human menu.
   c. Otherwise propose a scoped fix for the failing findings. If `advisor.enabled`
      is true, dispatch the Checkpoint-C advisor consult: a one-shot `Agent`
      subagent (`subagent_type: general-purpose`, `model:` = resolved advisor model)
      with ONLY the previously-failing findings, the current `git diff main...HEAD`,
      and - if `outcome.iteration > 1` - the prior iteration's attempted fix and the
      grader's response to it (loop memory, so it does not re-propose a failed fix).
      Ask it for a scoped fix plan, <= 80 words. Append `{phase: implement,
      checkpoint: C, verdict: <proceed|revise>, reasons: [...], ts: ...}` to
      `advisor.calls`; add history `advisor_consult` (`checkpoint C: <verdict>`).
      If `advisor.enabled` is false, derive the fix from the failing findings directly
      (no consult). On a subagent error, append `{phase: implement, checkpoint: C,
      verdict: failed, reasons: [error], ts: ...}` to `advisor.calls`, add history
      `advisor_failed`, and derive the fix from the findings directly.
   d. The **session model** applies the scoped fix inline, commits it, and appends
      the new SHA to `phases.implement.commits`; add history `commit_created`.
   e. Log one line to the user: `Outcome iteration <n>/<max>: FAIL on <finding> -> applied <fix>`.
      If this finding has now appeared on a second task in the round, the code fix
      is not the whole fix: add a mechanical check to `scripts/gate.sh` if it is
      detectable, or a rule to the round conventions file if it needs judgment.
      See conventions W2.
   f. Re-run the whole gate, L1 through L4, against the updated diff - not just
      the layer that failed. A fix for an acceptance criterion routinely breaks a
      test, and a scoped re-run would not see it. Return to step 1 with the new
      verdicts.

### Human Menu (reached on exhausted or ungraded)

Display the existing results block, then:

- **proceed**: accept the current diff and continue to `### Transition to PR`.
- **fix**: the human describes a manual fix; apply it, RESET `outcome.iteration` to 0,
  and re-enter the Outcome Loop.
- **override**: log history `override` and proceed with a warning.
- **waiver**: the human waives the WHOLE gate (Approach 1 has no per-item waiver);
  set `outcome.status: waived`, log history `waiver` with the reason, and proceed.
- **pause**: save state and exit.

### Degradation

Degradation is layered, and each layer degrades differently:

- **A reviewer inside L4 fails.** When lok runs it, its `health_check` probes
  each backend, a failed reviewer emits `REVIEW_FAILED`, and synthesis proceeds
  on whoever answered. When the native fan-out runs it, adjudicate on the
  reviews that returned. Do not substitute your own review for a failed one.
- **All of L4 fails.** Set `gate.llm_layer: none` with the reason and grade on
  L1-L3. This is a weaker gate, not an absent one.
- **A binding layer cannot run** (`scripts/gate.sh` exits 2: no cargo, no
  pyyaml, no task file to read criteria from). This is the only `ungraded` case.
  Fix the environment rather than proceeding: an unrunnable referee is the
  problem, not the verdict.

### Update State

- `phases.implement.gate_run: true`
- `phases.implement.validation_reports: [<paths>]` (empty if L4 did not run)
- `gate.layers: [{layer, verdict, note}, ...]` from the runner's summary
- `gate.deterministic_verdict: [PASS | FAIL | INCOMPLETE]`
- `gate.llm_layer: [lok | native | none]`
- Add history entry: `gate_run` (details: tier and verdict)
- `outcome.status` (`satisfied` | `exhausted` | `waived` | `ungraded`)
- `outcome.iteration` (final count)

### Transition to PR

- `phases.implement.status: complete`
- `workflow.current_phase: pr`
- `workflow.status: in_progress`
- **Continue to PR phase**

---

## YAML Checkpoint (Required before transition)

Before signaling completion to the dispatcher, verify:
- `phases.implement.status: complete`
- `phases.implement.commits` is non-empty
- History contains `implementation_complete`
- `phases.implement.gate_run` is true and `gate.deterministic_verdict` is resolved
- `gate.llm_layer` names which backend ran, including `none`
- `outcome.status` is resolved (not `pending`) when `outcome.max_iterations > 0`
- Any loop fix commits appear in `phases.implement.commits`
