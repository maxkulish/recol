# Phase: Status Display

**Purpose**: Display current workflow state when invoked with `--status` flag.

**Entry conditions**: `--status` flag provided

---

## Instructions

Read the workflow YAML file and display the appropriate status format based on task type.

---

## Development Task Status

```
========================================
WORKFLOW STATUS: REC-XX
========================================

Title: [Task title]
Type: Development
Current Phase: [phase] ([status])
Overall Progress: [X]%

Phases:
  [x] Discovery  - Complete (approach: [chosen approach])
  [x] Design     - Complete (docs/designs/rec-XX-[...].md)
  [x] Plan       - Complete (docs/plans/rec-XX-[...].md)
  [~] Implement  - In Progress (60% - Phase 3 of 5)
  [ ] PR         - Pending
  [ ] Complete   - Pending

Recent History:
  - [timestamp] phase_completed: Phase 2 - Core Implementation
  - [timestamp] commit_created: abc1234
  - [timestamp] pushed_to_remote

Files:
  - Workflow: docs/status/rec-XX-workflow.yaml
  - Design: docs/designs/rec-XX-[description].md
  - Plan: docs/plans/rec-XX-[description].md
  - Status: docs/status/rec-XX-[description].md

Branch: feat/rec-XX-short-desc
Linear: https://linear.app/cloud-ai/issue/REC-XX
```

---

## Specification Task Status

```
========================================
WORKFLOW STATUS: REC-XX
========================================

Title: [Task title]
Type: Specification
Current Phase: [phase] ([status])
Overall Progress: [X]%

Phases:
  [-] Design     - Skipped (specification task)
  [x] Spec       - Complete (specs/[date]-rec-XX-[slug].md)
  [~] Implement  - In Progress (40% - Phase 2 of 5)
  [ ] PR         - Pending
  [ ] Complete   - Pending

Recent History:
  - [timestamp] spec_approved: 5-section spec
  - [timestamp] phase_completed: Phase 1
  - [timestamp] pushed_to_remote

Files:
  - Workflow: docs/status/rec-XX-workflow.yaml
  - Spec: specs/[date]-rec-XX-[slug].md
  - Status: docs/status/rec-XX-[description].md

Branch: feat/rec-XX-short-desc
Linear: https://linear.app/cloud-ai/issue/REC-XX
```

---

## Operational Task Status

```
========================================
WORKFLOW STATUS: REC-XX
========================================

Title: [Task title]
Type: Operational
Current Phase: [phase] ([status])
Overall Progress: [X]%

Phases:
  [-] Design     - Skipped (operational task)
  [-] Plan       - Skipped (operational task)
  [~] Execute    - In Progress
  [ ] Document   - Pending
  [ ] PR         - Not required (no code changes)
  [ ] Complete   - Pending

Recent History:
  - [timestamp] checkpoint_reached: Task completed
  - [timestamp] finding_documented: New insight
  - [timestamp] status_file_updated

Files:
  - Workflow: docs/status/rec-XX-workflow.yaml
  - Status: docs/status/rec-XX-[description].md

Branch: feat/rec-XX-short-desc
Linear: https://linear.app/cloud-ai/issue/REC-XX
```

---

## Progress Calculation

- **Development**: 6 phases (Discovery=17%, Design=33%, Plan=50%, Implement=67%, PR=83%, Complete=100%)
- **Specification**: 4 phases (Spec=25%, Implement=50%, PR=75%, Complete=100%)
- **Operational**: 4 phases (Execute=25%, Document=50%, PR=75%, Complete=100%)
- Within Implement phase, calculate sub-progress from completed plan phases
