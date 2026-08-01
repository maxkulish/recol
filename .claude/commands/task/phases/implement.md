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

---

## Step 5: Codex + Gemini Validation Gate

**After implementation is complete, before creating a PR**, run external model validation to catch issues Claude may have blind spots for.

### Run the validation gate via `lok`

The codex + gemini + synthesis pipeline lives in
`.lok/workflows/implement-gate.toml`. Invoke it and let the workflow engine
own prompt assembly, parallel reviewer dispatch, output validation, the
Claude fallback, and the synthesis write. Do **not** reinvent it inline.

```bash
# arg.1 = task ID (lowercase),  arg.2 = branch name
lok workflow run implement-gate rec-XX feat/rec-XX-<slug>
```

Optional environment overrides:

| Variable | Default | Purpose |
|---|---|---|
| `CODEX_MODEL` | `gpt-5.6-sol` | Codex model used for the codex reviewer |
| `GEMINI_MODEL` | `gemini-3.1-pro-preview` | Primary Gemini model |
| `GEMINI_FALLBACK_MODEL` | `gemini-3.6-flash` | Used if the primary returns empty |

Gemini is reached through `opencode run --model "google/$MODEL" --agent plan`.
The standalone `gemini` CLI is deprecated and must not be called from this
phase.

The workflow writes (and the rest of this step reads):

- `docs/reviews/rec-XX-codex-validation.md`
- `docs/reviews/rec-XX-gemini-validation.md`
- `docs/reviews/rec-XX-validation-synthesis.md`

If both external reviewers fail, the workflow runs a Claude fallback into
`docs/reviews/rec-XX-claude-fallback-validation.md`. Synthesis still runs
and produces the binding verdict.

Anti-pattern (do not do this): writing a scratch script that shells out to
`codex exec` or `gemini` directly. That bypasses the workflow's output
validators, fallback logic, and synthesis step, and it hardcodes models that
drift over time. Always go through `lok`.

If `lok workflow run` exits non-zero, or any of the three required files is
missing or empty, treat the gate as failed: do not transition phases. Mark
the workflow blocked, re-run with `--verbose`, read the reviewer stderr the
failing step names, fix the root cause, and re-run. Never hand-write a
review file.

### Display Results

```
VALIDATION GATE RESULTS (REC-XX)
=================================

Codex (gpt-5.6-sol):
  Report: docs/reviews/rec-XX-codex-validation.md
  Key Findings: [top 3 findings]

Gemini (gemini-3.1-pro-preview, via opencode):
  Report: docs/reviews/rec-XX-gemini-validation.md
  Key Findings: [top 3 findings]

Synthesis (binding):
  Verdict: [approve | approve_with_changes | pivot | rework]
  Report: docs/reviews/rec-XX-validation-synthesis.md

Options:
1. [proceed]  - Continue to PR creation
2. [fix]      - Address findings before PR (recommended if FAIL)
3. [override] - Skip validation and proceed (not recommended)
4. [pause]    - Pause workflow

Your choice:
```

### Outcome Loop (grade-and-retry, Checkpoint C)

The binding verdict is the `## Verdict` line at the end of
`docs/reviews/rec-XX-validation-synthesis.md`. Do not re-derive it by combining
the raw reviewer reports: they are inputs to synthesis, not graders in their own
right. Map it onto the loop states below.

| Synthesis verdict | Loop state |
|---|---|
| `approve` | PASS |
| `approve_with_changes` | PASS_WITH_NOTES |
| `pivot`, `rework` | FAIL |

Then, if `outcome.max_iterations` is `0`, skip the loop and go straight to
the human menu below (Step-5 behaves as it did before this feature).

Otherwise run:

1. **Grader unavailable** (the synthesis report is missing, empty, or reads
   `NO_REVIEWS_AVAILABLE` after the Claude fallback also failed): set
   `outcome.status: ungraded`, add history `outcome_ungraded`, and go to the
   human menu. Do not iterate without a grader.
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
   f. Re-run the gate: `lok workflow run implement-gate rec-XX feat/rec-XX-<slug>`.
      The workflow owns its prompt, so the re-run is full rather than scoped to the
      previously-failing findings; it re-reads the updated diff and overwrites the
      three review files. Return to step 1 with the new synthesis verdict.

### Human Menu (reached on exhausted or ungraded)

Display the existing results block, then:

- **proceed**: accept the current diff and continue to `### Transition to PR`.
- **fix**: the human describes a manual fix; apply it, RESET `outcome.iteration` to 0,
  and re-enter the Outcome Loop.
- **override**: log history `override` and proceed with a warning.
- **waiver**: the human waives the WHOLE gate (Approach 1 has no per-item waiver);
  set `outcome.status: waived`, log history `waiver` with the reason, and proceed.
- **pause**: save state and exit.

### Fallback

Reviewer degradation is handled inside the workflow, not here. Its
`health_check` step probes each backend, a failed reviewer emits
`REVIEW_FAILED` and synthesis proceeds on whoever answered, and if both
external reviewers fail the `claude_fallback` step supplies the review that
feeds synthesis. Do not substitute your own reviewer for a failed one.

The only case this step handles is the workflow not producing a usable
synthesis at all: `lok workflow run` exits non-zero, or the synthesis file is
missing, empty, or reads `NO_REVIEWS_AVAILABLE`. Then the outcome loop sets
`outcome.status: ungraded` and routes to the Human Menu.

### Update State

- `phases.implement.codex_validated: true`
- `phases.implement.codex_verdict: [verdict]`
- `phases.implement.codex_report: docs/reviews/rec-XX-codex-validation.md`
- `phases.implement.gemini_validation_report: docs/reviews/rec-XX-gemini-validation.md`
- `phases.implement.validation_synthesis_report: docs/reviews/rec-XX-validation-synthesis.md`
- `phases.implement.validation_synthesis_verdict: [approve | approve_with_changes | pivot | rework]`
- Add history entry: `codex_validation_complete`
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
- `phases.implement.codex_validated` is set (true if ran, false if skipped/unavailable)
- `outcome.status` is resolved (not `pending`) when `outcome.max_iterations > 0`
- Any loop fix commits appear in `phases.implement.commits`
