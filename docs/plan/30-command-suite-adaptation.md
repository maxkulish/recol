# 30 - Command suite adaptation to the 2026-08 migration guidance

**Status**: Proposed (analysis complete 2026-08-07, not yet started)
**Scope**: `.claude/commands/`, `.claude/templates/workflow-state.yaml`, and how R0+ rounds run through them
**Sources**: `~/Work/investigations/claude/guides/` at index 1.19.0 (2026-08-06), which absorbed
[Anthropic - How Anthropic runs large-scale code migrations with Claude Code](https://claude.com/blog/ai-code-migration).
Load-bearing sections: Guide 06 Pattern 9, Production Discipline §B.6 + A.2,
Reasoning & Specification §C.2.6 + §C.3, Guide 05 Part D, Guide 13 v1.1.0.
**Session evidence**: `.session/notes.md` F6-F9 (2026-08-07 session).

---

## Why this plan exists

The command suite already implements Guide 13 v1.0.0: advisor consults at
checkpoints A/B/C and the bounded outcome loop in `task/phases/implement.md`.
The 2026-08-06 guide pass added the production-side half of Anthropic's
migration methodology, and the first real run of the suite in this repository
(R0-01, recorded in `docs/status/r0-01-workflow.yaml`) demonstrated exactly the
gaps that pass names:

- The outcome loop resolved `ungraded` because the mandated grader
  (`lok workflow run implement-gate`, backed by `.lok/workflows/implement-gate.toml`)
  does not exist in this repository. Spec review skipped for the same reason
  (`phases.spec.review_unavailable_reason` in the R0-01 YAML). Per Production
  Discipline §B.6: no referee, no loop.
- Three of four Qodo review rounds were findings about the workflow YAML audit
  trail itself, and the state file at one point did not parse as YAML while all
  local gates were green. The lesson recorded in the YAML ("one yaml.safe_load
  loop over docs/status/*.yaml would have caught it") is a fix-the-loop
  amendment with no mechanism to land in.
- The orchestrator is hardcoded to Linear REC-XX
  (`task/phases/init.md` Step 2, `mcp__linear-server__get_issue`), while the
  live work is file-based R0-XX in `docs/tasks/`. R0-01 improvised every skip
  by hand with per-field `skip_reason` prose.

## What is already right (do not rebuild)

- Advisor checkpoints A/B/C and the outcome loop are faithful Guide 13 ports,
  including skip/failed semantics, per-checkpoint call caps, and the human
  waiver path.
- The R0 task system is independently ahead of the commands:
  - Runnable acceptance criteria in each task file are test-suite-as-spec
    (Reasoning & Spec §C.2.4).
  - `docs/tasks/README.md`'s dependency ordering with verified traps is a
    hand-built gap inventory (§C.2.6).
  - Sequencing R0-00 (make CI run) first is §B.6's "judge is milestone zero".
  - R0-08's "the audit must fail on the current tree" is negative validation
    of a referee.
- `project/sync.md` is the style target: 147 lines, documents real file
  shapes, a "Does not" section, rules grounded in dated incidents.

## Gap inventory, ranked by leverage

1. **Grader unreachable** (§B.6). `implement.md:75-118` mandates lok;
   `spec.md:39-57` and `design-doc/review.md:230` need
   `.lok/workflows/{spec-review,design-review}.toml`. No `.lok/` exists here,
   and the phase files forbid workarounds, so the quality machinery silently
   degrades to human-only. No gate anywhere is negatively validated.
2. **Acceptance Contract chain severed.** `design-doc/create.md:211` requires
   measurable criteria; `plan/create.md:177-259` output template has no
   Acceptance Criteria section; `/plan:implement` therefore validates on
   `cargo test` alone. The R0 task files carry the right contract shape and
   the orchestrator cannot consume them.
3. **State file over disk** (Pattern 9 / Guide 06 Anti-Pattern 4). The YAML is
   treated as source of truth; the stronger form derives done-ness from disk
   (plan file exists, commits exist, `gh pr view` answers) with YAML as audit
   trail. `orchestrate.md` Step 3.5's backfill is already half of this.
4. **No fix-the-loop mechanism.** Recurring review findings should amend the
   gate (add a mechanical check), not just fix the instance.
5. **Verification placement ignores wall-clock** (Pattern 9). Everything is
   end-loaded after 100% implementation. Fast checks belong in-loop per
   commit; expensive checks once at the phase boundary.
6. **Rot and duplication** (Context Stack §C.15 contradiction cost).
   ~1,400 of 4,787 lines across the nine non-task commands are duplicated
   boilerplate. Cross-project residue: audio-app examples in
   `pr/review.md:705-975`, `remem-ai` naming in `design-doc/review.md:76`,
   "60+ ADR files" vs actual 2 at `design-doc/review.md:68`, nonexistent
   personas at `design-doc/review.md:310-313`. Four broken seams:
   - a. Design review's only gate runs through missing `.lok/`.
   - b. `design-doc/finalize.md:168` git-adds `rec-XX-design-review.md`, a
     filename `/design-doc:review` never writes.
   - c. Plan template drops acceptance criteria (gap 2).
   - d. `pr/finalize.md:158-228` edits `PROJECT.md`/`ROADMAP.md`/
     `DEPENDENCIES.md`, which do not exist; `project/sync.md:16` documents
     that as a past bug. finalize is the unfixed earlier version.
7. **Guide 13 v1.1.0 drift** (minor). `templates/workflow-state.yaml:109-110`:
   effort enum reads `high | max` (missing `xhigh`); the model comment
   suggests `claude-fable-5` where the guide default is `claude-opus-5`
   (Fable reserved for the hardest consults).

---

## The plan: three reversible steps

Each step is independently valuable and landable as its own PR, mirroring the
Guide 13 Part E rollout discipline.

### Step 1 - Rebuild the referee as a repo-level gate contract

Do this before running R0-02 through the orchestrator.

- Replace the hard lok dependency in `task/phases/implement.md` Step 5 with a
  gate contract declared in the workflow YAML (`gate:` block). Ladder per
  Production Discipline §B.2, deterministic first, model judgment last:
  1. Run the task file's acceptance criteria verbatim (they are commands).
  2. `cargo fmt --check && cargo check && cargo test --workspace`.
  3. YAML validity sweep: `python3 -c` loop with `yaml.safe_load` over
     `docs/status/*.yaml` (the R0-01 lesson, promoted into the loop).
  4. Optional LLM layer: vendored `.lok/` workflows (Codex + Gemini) if
     wanted, or native subagent fan-out. Absence of this layer must not
     resolve the outcome to `ungraded` when layers 1-3 ran.
- Same substitution for `spec.md` Step 2 and `design-doc/review.md` Step 6:
  when `.lok/` is absent, fall back to native Agent-tool reviewer fan-out
  instead of skipping review entirely.
- **Negative validation** (§B.6 step 3): after wiring, seed one deliberate
  breakage (e.g. revert an acceptance-criterion-covered change on a scratch
  branch), run the gate, and confirm FAIL. Record the validation in the
  round's conventions file. A gate that has never failed proves nothing.
- Payoff beyond correctness: per Production Discipline A.2, a validated
  deterministic verifier legitimately buys the implement phase one autonomy
  tier.

### Step 2 - Make the file-based task track first-class

- `task/phases/init.md`: a task ref matching `R\d+-\d+` resolves to
  `docs/tasks/r*-*.md` instead of Linear. The task file is the spec
  (formalizing R0-01's improvisation): `spec.spec_file` points at it,
  acceptance criteria flow into the Step 1 gate, `project.md` is the board.
  `linear_url: null` is a valid state, not an error.
- `project/sync.md`: accept R0-NN ids (it already documents the real
  `project.md` shape; it only lacks the id form).
- Disk-derived done-ness: in `orchestrate.md` Step 3.5, check disk/gh first
  (plan file exists, commits reachable, PR state via `gh pr view`) and treat
  the YAML as audit trail to reconcile, not as the authority to trust.
- Two Pattern 9 disciplines, scoped to what fits per-task rounds:
  - **Flag-and-defer** (§C.3): mid-task discoveries owned by another task get
    a marker and a `deliberately_not_changed` entry (R0-01 did this ad hoc
    for AGENTS.md; make it the convention) instead of scope creep.
  - **Fix-the-loop**: a reviewer finding that recurs across tasks must
    produce a new mechanical gate check or a conventions-file rule, recorded
    with the finding that minted it. The code is never the only fix site.
- A round conventions file (`docs/plan/20-rename-and-release/conventions.md`
  or equivalent) as the lightweight rulebook: reviewers cite it, recurring
  findings amend it.

### Step 3 - Rightsize the suite

- Fix the four broken seams: (a) resolved by Step 1; (b) correct the filename
  in `design-doc/finalize.md:168` to the synthesis report the review actually
  writes; (c) add an Acceptance Criteria section to the plan template in
  `plan/create.md` and have `plan/implement.md` execute it per phase;
  (d) delete `pr/finalize.md` Step 6 and call `/project:sync --complete`.
- Dedupe toward `project/sync.md`'s style. Biggest wins first:
  - Collapse the three per-bot sections in `pr/review.md:623-1017`
    (~390 lines) into the generic Steps 3-9 plus the reviewer table.
  - Extract shared preludes (task-id resolution, branch conventions, Linear
    comment shapes, workflow-YAML mutation) to `.claude/templates/`;
    `pr/finalize.md:342` already proves the delegation pattern.
  - Delete the dead second PR-body template (`pr/create.md:305-380`), the
    worked-example recaps, and the "Implementation Notes"/"Philosophy"
    trailers.
- Purge cross-project residue: audio examples, `remem-ai`/`lok.toml`
  references, wrong ADR counts, `docs/arch` and `docs/plans` path typos,
  nonexistent persona names.
- Guide 13 v1.1.0 alignment in `templates/workflow-state.yaml`: effort enum
  `high | xhigh | max`; model comment recommends `claude-opus-5` as advisor
  default with `claude-fable-5` reserved for the hardest consults.
- Two-tier verification in `plan/implement.md`: fast checks
  (`cargo fmt --check`, `cargo check`, YAML sweep) per task; full
  `cargo test --workspace` and the LLM layer once at phase end.

## Boundary: what NOT to adopt

Full Pattern 9 machinery (build daemon, rule stress tests, thousand-file
disk-derived queues) is wrong for R0: its 19 tasks are heterogeneous, which is
the pattern's stated anti-trigger ("if each unit needs a different decision,
that is Pattern 7/8 territory"). Adopt the referee, queue-from-disk, and
fix-the-loop elements now. Reserve the full loop for genuinely fleet-shaped
work (R1 replay/reingest, a future mass rename), where a deterministic
dependency-map script (Guide 05 Part D) should also replace hand-discovered
ordering of the kind `docs/tasks/README.md` currently encodes by inspection.

Also note the Guide 13 Part D inversion: per-task 80/20 tiering (cheap
executors, one expensive advisor consult) holds for this driver; on
migration-shaped fleet work the largest models move to reviewers and
rule-writers instead. Do not carry the per-task defaults into a future fleet
round unexamined.

## Verification for this plan itself

- Step 1 done when: `lok`-less `rec`/`r0` run reaches a resolved
  `outcome.status` other than `ungraded`, and the seeded-breakage run is
  recorded as FAIL-then-fixed.
- Step 2 done when: an R0 task runs `/task:orchestrate R0-XX` end-to-end with
  zero hand-written `skip_reason` prose and `git grep -c skip_reason
  docs/status/<that-task>-workflow.yaml` returns only template-provided
  entries.
- Step 3 done when: `rg -l 'PROJECT\.md|ROADMAP\.md|DEPENDENCIES\.md'
  .claude/commands` returns only `project/sync.md` (its historical note), and
  `rg -l 'src/audio|remem-ai|lok\.toml' .claude/commands` returns nothing.
