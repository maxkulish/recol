---
context: fork
allowed-tools:
  - Read
  - Glob
  - Bash(ls:*)
  - Bash(mkdir:*)
  - Bash(lok:*)
  - Bash(opencode:*)
  - Write
---

# /design-doc:review - AI Review of Design Documents

**Purpose**: Automatically review design documents using multiple AI models (Gemini + Ollama/Codex) with Claude as a guaranteed fallback. Identifies architectural issues, ADR compliance, blind spots, and provides actionable feedback before human review.

**Usage**:
- `/design-doc:review REC-XX` - Review with both models + Claude fallback if needed
- `/design-doc:review REC-XX --model gemini` - Gemini only
- `/design-doc:review REC-XX --model ollama` - Ollama only
- `/design-doc:review REC-XX --persona all` - Run all domain-specific persona reviews
- `/design-doc:review` - Interactive mode

**Resilience guarantees**:
- Pre-flight health check skips unreachable models immediately (no 5-minute timeout waste)
- Empty output short-circuit avoids burning validator API calls on trivially detectable failures
- Gemini falls back to `GEMINI_FALLBACK_MODEL` after empty output from primary model
- Claude fallback reviewer activates when both external models fail - at least one review is always produced
- Synthesis adapts format: multi-review (Agreement/Disagreement) vs single-review (Key Findings)

---

## Key Differences: Gemini vs Ollama (via Codex)

| Aspect | Gemini (via opencode) | Ollama (Codex) |
|--------|-----------|----------------|
| **File Reading** | Agent reads files itself | Shell commands in read-only sandbox (`cat`, `find`, `head`) |
| **Directory Access** | Full project read access from the run directory | Full project read access via `--sandbox read-only` |
| **Approach** | Model reads files itself | Agent reads files via shell |
| **Command** | `opencode run --model "google/gemini-3.1-pro-preview" --agent plan -- "..."` | `ollama launch codex --model MODEL -- exec "..." --sandbox read-only --oss --local-provider ollama` |
| **Sandbox** | opencode `plan` agent (read-only, no edits) | Codex `--sandbox read-only` (no writes allowed) |

The standalone `gemini` CLI is deprecated. Reach Gemini only through
`opencode run --model "google/$MODEL"`, matching `.lok/workflows/*.toml`.

---

## When to Use

This command is typically invoked:
1. Automatically by `/task:orchestrate` after `/design-doc:create` completes
2. Manually when requesting an AI review of any design document

---

## Unified Review Prompt

**Both Gemini and Codex receive the same review prompt.** Only the file-reading instructions differ slightly.

```
You are a senior software architect reviewing a design document.

TASK: Review the design document at: docs/designs/[DESIGN_DOC_FILENAME]

Read these files to gather context:
1. docs/designs/[DESIGN_DOC_FILENAME] — The design document to review
2. docs/adr/ — Architecture documents (read all .md files in this directory)
3. docs/adr/ — Architecture Decision Records (60+ files). List filenames first, then read ONLY the ADRs relevant to this design document's topic (typically 5-10 most relevant)
4. docs/plan/01-roadmap.md — Current project phase and task status
5. docs/tasks/README.md — Task dependency graph
6. project.md — Active work and blockers

If the design document references specific source files, read those too for validation.

PROJECT CONTEXT:
- This is a Rust crate (Cargo, edition 2021) named remem-ai - a local-first coding-agent memory system for Claude Code and OpenAI Codex; lib `remem`, bin `remem`
- Linear workspace: cloud-ai
- Issue prefix: REC

REVIEW CRITERIA:

1. COMPLETENESS (check all sections are present and meaningful)
   - Summary: Clear problem statement and solution
   - Background: Sufficient context
   - Architecture: Component overview
   - Detailed Design: Implementation approach
   - Implementation Plan: Phased approach with clear tasks
   - Acceptance Criteria: Testable success metrics

2. ARCHITECTURE QUALITY
   - Appropriate design patterns
   - Clear separation of concerns
   - Scalability considerations
   - Error handling strategy

3. ADR COMPLIANCE
   - List all ADR filenames in docs/adr/ to understand the full decision landscape
   - Read the ADRs most relevant to this design document's topic (typically 5-10)
   - For each relevant ADR, check if the design document follows or contradicts the decisions
   - Flag any violations or deviations from established ADRs
   - Note if the design document introduces patterns that should become a new ADR

4. CODE QUALITY
   - Clean interfaces
   - Proper abstractions
   - Testability

5. SECURITY POSTURE
   - Input validation
   - Authentication/Authorization (if applicable)
   - No hardcoded secrets

6. OPERATIONAL READINESS
   - Logging and monitoring considered
   - Error recovery addressed
   - Rollback plan exists

7. ARCHITECTURAL ALIGNMENT
   - Aligns with existing architecture (from docs/adr)
   - Follows established patterns
   - Fits within current project phase and dependencies

8. BLIND SPOTS
   - What is NOT covered in the design document that should be?
   - What edge cases or failure modes are missing?
   - What assumptions are made but not stated?
   - What cross-cutting concerns (logging, metrics, error handling, accessibility) are overlooked?
   - What integration points with existing code might cause unexpected issues?

OUTPUT FORMAT:

## 1. Completeness Check
[List sections present/missing with brief assessment]

## 2. Architecture Assessment
**Strengths**: [What's done well]
**Concerns**: [Issues to address]

## 3. ADR Compliance
[For each ADR in docs/adr/, state whether the design follows it]
**Violations**: [Any ADR violations found]
**New ADR Needed**: [If the design introduces patterns worthy of a new ADR]

## 4. Security Review
[Assessment of security posture]

## 5. Implementation Concerns
[Feedback on implementation plan]

## 6. Blind Spots
[What the design document misses or doesn't address]
- Missing edge cases
- Unstated assumptions
- Overlooked failure modes
- Missing cross-cutting concerns

## 7. Verdict
[One of: APPROVE | APPROVE_WITH_SUGGESTIONS | NEEDS_REVISION]

## 8. Actionable Feedback
[Prioritized list of specific, actionable items]
```

---

## Command Execution Instructions

### Step 1: Extract Task Number and Model Selection

1. **Parse arguments**:
   - Extract task number (e.g., `REC-21` or `rec-21`)
   - Check for `--model gemini`, `--model ollama`, or default to both
   - Check for `--persona [security|concurrency|backend-integration|all]` (optional, adds domain-specific reviews)

2. **If no task number provided**:
   - Ask: "Which design document do you want to review? (e.g., REC-21)"
   - Wait for response

### Step 2: Locate Design Document

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

**If found**: Note the full filename (e.g., `rec-21-websocket-handler.md`)

### Step 3: Verify Context Files

Verify these files exist (both models need them):
- `docs/designs/rec-XX-*.md` — The design document to review
- `docs/adr/` — Architecture documents directory
- `docs/adr/` — Architecture Decision Records (60+ files)
- `docs/plan/01-roadmap.md` — Project phases and task status
- `docs/tasks/README.md` — Task dependency graph
- `project.md` — Active work and blockers

If any are missing, warn but proceed.

### Step 4: Create Reviews Directory

```bash
mkdir -p docs/reviews
```

### Step 5: Build the Review Prompt

Construct the unified prompt (from the template above) by replacing `[DESIGN_DOC_FILENAME]` with the actual filename. **Both models get the same prompt.**

### Step 6: Run AI reviews

Use the first backend that is actually present. A design doc that no second
reader ever saw is worse than a slow review, so this step never resolves to
"skipped" while any backend remains.

**Backend A - lok**, if `.lok/workflows/design-review.toml` exists in this repo.
The workflow executes this pipeline:

1. **Health check** (10s) - verifies Gemini CLI and Ollama are reachable. Unreachable models are skipped immediately instead of timing out after 300s.
2. **Gemini review** (up to 300s) - runs primary model, falls back to `GEMINI_FALLBACK_MODEL` on empty output.
3. **Ollama review** (up to 300s) - runs in parallel with Gemini, short-circuits on empty output.
4. **Claude fallback** (up to 120s) - runs only if both Gemini and Ollama failed. Reads the design doc and context files directly to guarantee at least one review.
5. **Synthesis** - cross-references all successful reviews, includes reviewer status table with failure reasons.
6. **Write files** - saves individual reviews and synthesis.

Run in background:
```bash
lok run .lok/workflows/design-review.toml \
  "docs/designs/[DESIGN_DOC_FILENAME]" \
  "rec-[XX]" \
  --dir . \
  --verbose
```

This produces:
- `docs/reviews/rec-[XX]-review-gemini.md` (validated Gemini review or REVIEW_FAILED)
- `docs/reviews/rec-[XX]-review-ollama.md` (validated Ollama review or REVIEW_FAILED)
- `docs/reviews/rec-[XX]-review-claude-fallback.md` (only if both external models failed)
- `docs/reviews/rec-[XX]-review-synthesis.md` (cross-referenced synthesis with reviewer status)

**Backend B - native fan-out**, when there is no `.lok/` in this repo. Dispatch
two reviewer subagents with the `Agent` tool
(`subagent_type: general-purpose`) in a single message so they run
concurrently. Give each the design document, the context files from Step 3, and
the unified prompt from Step 5, but assign each a different half of it:

| Subagent | Prompt sections it answers |
|---|---|
| `review-architecture` | 1 Completeness, 2 Architecture, 3 ADR Compliance, 7 Verdict, 8 Actionable Feedback |
| `review-risk` | 4 Security, 5 Implementation Concerns, 6 Blind Spots, 7 Verdict, 8 Actionable Feedback |

Splitting the prompt rather than duplicating it is deliberate: two agents given
the same prompt and the same model return the same review twice, which reads
like agreement and is not. Write the results to
`docs/reviews/rec-[XX]-review-architecture.md` and
`docs/reviews/rec-[XX]-review-risk.md`; Step 8 synthesizes them exactly as it
would the lok outputs.

**Backend C - none**: nothing was reachable. Report `NO_REVIEWS_AVAILABLE` and
say plainly at the checkpoint that the design is unreviewed. Never present an
unreviewed design as reviewed.

### Step 7: Save Review Outputs

**Gemini review**: `docs/reviews/rec-XX-review-gemini.md`
**Ollama review**: `docs/reviews/rec-XX-review-ollama.md`

**Format for each**:
```markdown
# Design Review: REC-XX - [Title]

**Reviewed**: [Current Date YYYY-MM-DD]
**Reviewer**: [Gemini 3.1 Pro | Codex via Ollama (glm-5:cloud)]
**Design Document**: docs/designs/rec-XX-[description].md
**Review Duration**: [X seconds]

---

[AI REVIEW OUTPUT]

---

*This review was automatically generated. Human judgment should be applied when interpreting these suggestions.*
```

### Step 7.5: Run Persona Reviews (if --persona flag provided)

If `--persona` flag was provided, run additional domain-specific reviews. These run as Claude subagents, each reading the persona template and the design document.

**Available personas** (templates in `.claude/templates/review-personas/`):

| Persona | Template | Focus |
|---------|----------|-------|
| `security` | `review-personas/security.md` | API key handling, process execution, input validation |
| `concurrency` | `review-personas/concurrency.md` | Async safety, tokio patterns, race conditions |
| `backend-integration` | `review-personas/backend-integration.md` | Backend trait, error handling, timeout management |

**For each requested persona** (or all three if `--persona all`):

1. Read the persona template from `.claude/templates/review-personas/{persona}.md`
2. Build the persona review prompt by combining the template's review prompt with:
   - The design document path
   - Relevant source files (based on persona focus)
   - The persona's output format
3. Run as a subagent (Agent tool) with the persona prompt
4. Save output to `docs/reviews/rec-XX-review-{persona}.md`

**Output files**: `docs/reviews/rec-XX-review-security.md`, etc.

---

### Step 8: Analyze All Reviews and Produce Synthesis

After every review from the Step 6 backend completes (plus optional personas), read all review files and produce a synthesis following the template at `.claude/templates/review-synthesis.md`. The synthesis does not care which backend produced the reviews:

```markdown
## Review Synthesis

### Agreement (High Confidence)
[Items where 2+ reviewers independently identified the same concern]

### Disagreement (Needs Human Decision)
[Items where reviewers hold divergent positions]

### Novel Insights (Single Reviewer)
[Items found by only one reviewer]

### Persona Summary (if applicable)
| Persona | Verdict | Key Finding |
|---------|---------|-------------|
| Audio Safety | [verdict] | [1-line summary] |
| FFI Safety | [verdict] | [1-line summary] |
| State Machine | [verdict] | [1-line summary] |

### Consolidated Verdict
[Apply consensus rules: ANY NEEDS_REVISION -> NEEDS_REVISION, all APPROVE -> APPROVE, else APPROVE_WITH_SUGGESTIONS]

### Priority Actions
1. [Highest priority - agreement items first]
2. [Second priority]
3. [Third priority]
```

Save synthesis to `docs/reviews/rec-XX-review-synthesis.md`.

### Step 9: Return Summary

```
========================================
DESIGN REVIEW COMPLETE
========================================

Design Document: docs/designs/rec-XX-[description].md

Reviews Generated:
  - docs/reviews/rec-XX-review-gemini.md (Xs)
  - docs/reviews/rec-XX-review-ollama.md (Xs)
  - docs/reviews/rec-XX-review-synthesis.md
  [If personas ran:]
  - docs/reviews/rec-XX-review-security.md
  - docs/reviews/rec-XX-review-concurrency.md
  - docs/reviews/rec-XX-review-backend-integration.md

Verdicts:
  - Gemini: [APPROVE | APPROVE_WITH_SUGGESTIONS | NEEDS_REVISION]
  - Ollama: [APPROVE | APPROVE_WITH_SUGGESTIONS | NEEDS_REVISION]
  [If personas ran:]
  - Security: [SAFE | CONCERNS_HIGH | CONCERNS_MEDIUM]
  - Concurrency: [SAFE | CONCERNS_HIGH | CONCERNS_MEDIUM]
  - Backend Integration: [CORRECT | CONCERNS_HIGH | CONCERNS_MEDIUM]

Consensus: [APPROVE | NEEDS_REVISION | MIXED]

Key Findings:
1. [Top finding from synthesis]
2. [Second finding]
3. [Third finding]

Full reviews saved to: docs/reviews/
```

---

## Error Handling

**Check review results**

Read `docs/reviews/rec-[XX]-review-synthesis.md`. The synthesis always starts with a **Reviewer Status** table showing which models succeeded, failed, or were skipped.

**Interpreting the synthesis:**

| Scenario | Synthesis format | What happened |
|----------|-----------------|---------------|
| 2+ reviews valid | Multi Review (Agreement/Disagreement/Novel) | Normal multi-perspective synthesis |
| 1 review valid | Single Review (Key Findings) | One external model + possibly Claude fallback |
| Claude fallback only | Single Review, source = Claude | Both external models failed, fallback activated |
| `NO_REVIEWS_AVAILABLE` | Status table only | All reviewers failed (rare - Claude fallback should prevent this) |

**Failure diagnostics:**

The Reviewer Status table in the synthesis includes failure reasons inline:

```
## Reviewer Status
| Reviewer | Status | Detail |
|----------|--------|--------|
| Gemini | REVIEW_FAILED | Network timeout after 300s |
| Ollama | REVIEW_FAILED | Empty output, CLI startup failure |
| Claude (fallback) | OK | Produced full review |
```

For deeper diagnostics:
- Gemini stderr: `/tmp/lok-gemini-stderr.log`
- Ollama stderr: `/tmp/lok-ollama-stderr.log`

**The `NO_REVIEWS_AVAILABLE` case should be rare.** Every fallback below lok has no external dependencies: the Claude fallback inside the workflow reads files directly, and Backend B's native fan-out needs nothing but the session's own `Agent` tool. Reaching `NO_REVIEWS_AVAILABLE` means the pipeline itself is broken, not that the network is down.

---

## Configuration

### Default Models

| Provider | Model | Integration | Notes |
|----------|-------|-------------|-------|
| Gemini | `gemini-3.1-pro-preview` | Gemini CLI | Explicitly set via `--model` flag to prevent auto-routing to Flash |
| Ollama | `glm-5:cloud` | Codex | `ollama launch codex --model MODEL --oss --local-provider ollama` |

### Environment Variables

- `GEMINI_MODEL` - Override default Gemini model (default: `gemini-3.1-pro-preview`)
- `GEMINI_FALLBACK_MODEL` - Gemini model to try when primary returns empty output (default: `gemini-2.5-pro`)
- `OLLAMA_MODEL` - Override default Ollama model (default: `glm-5:cloud`)
- `GEMINI_TIMEOUT` - Override Gemini timeout in seconds (default: 300)
- `OLLAMA_TIMEOUT` - Override Ollama timeout in seconds (default: 300)

---

## Output Files

| File | Purpose | When created |
|------|---------|--------------|
| `docs/reviews/rec-XX-review-gemini.md` | Gemini AI review | Backend A (may contain REVIEW_FAILED) |
| `docs/reviews/rec-XX-review-ollama.md` | Codex/Ollama AI review | Backend A (may contain REVIEW_FAILED) |
| `docs/reviews/rec-XX-review-claude-fallback.md` | Claude fallback review | Backend A, only when both external models failed |
| `docs/reviews/rec-XX-review-architecture.md` | Completeness, architecture, ADR compliance | Backend B |
| `docs/reviews/rec-XX-review-risk.md` | Security, implementation concerns, blind spots | Backend B |
| `docs/reviews/rec-XX-review-synthesis.md` | Cross-referenced synthesis with reviewer status | Always |

Record whichever set was produced in `phases.design.review_reports`, and the
backend in `phases.design.review_backend`.

---

## Example: Running Both Reviews

```bash
DESIGN_DOC="rec-125-flat-model-list.md"
REVIEW_PROMPT="You are a senior software architect reviewing a design document.

TASK: Review the design document at: docs/designs/${DESIGN_DOC}

Read these files to gather context:
1. docs/designs/${DESIGN_DOC}
2. docs/adr/ (all .md files — Architecture Decision Records)
3. docs/plan/01-roadmap.md
4. docs/tasks/README.md
5. project.md

If the design document references specific source files, read those too.

PROJECT CONTEXT: Rust crate remem-ai - local-first coding-agent memory for Claude Code and OpenAI Codex. Linear workspace: cloud-ai. Issue prefix: REC.

[... full review criteria and output format ...]"

# Run Gemini (background)
(
  start=$(date +%s)
  timeout 300 opencode run --model "google/${GEMINI_MODEL:-gemini-3.1-pro-preview}" --agent plan \
    -- "$REVIEW_PROMPT" > docs/reviews/rec-125-review-gemini.md 2>&1
  echo -e "\n\n**Duration**: $(($(date +%s) - start))s" >> docs/reviews/rec-125-review-gemini.md
) &

# Run Ollama/Codex (background)
(
  start=$(date +%s)
  env -u CLAUDECODE timeout 300 ollama launch codex --model glm-5:cloud -- \
    exec "$REVIEW_PROMPT" \
    --sandbox read-only \
    --oss --local-provider ollama \
    --ephemeral \
    -o docs/reviews/rec-125-review-ollama.md
  echo -e "\n\n**Duration**: $(($(date +%s) - start))s" >> docs/reviews/rec-125-review-ollama.md
) &

# Wait for both
wait
echo "Both reviews complete."
```

---

## Integration Notes

**Called by**: `/task:orchestrate` after `/design-doc:create` completes

**Creates**:
- `docs/reviews/rec-XX-review-gemini.md` (always)
- `docs/reviews/rec-XX-review-ollama.md` (always)
- `docs/reviews/rec-XX-review-claude-fallback.md` (only when both external models failed)
- `docs/reviews/rec-XX-review-synthesis.md` (always)
- `docs/reviews/rec-XX-review-{persona}.md` (if --persona used)

**Updates**: Nothing (read-only analysis)
