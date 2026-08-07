# /plan:create - Create Implementation Plans from Design Documents or Linear Tasks

**Purpose**: Analyze design documents (if available) or Linear task details to generate step-by-step implementation plans with progress tracking.

**Usage**:
- `/plan:create [rec-XX]` - Create plan for specific task
- `/plan:create` - Interactive mode

---

## Project Context

Read `.claude/templates/task-context.md` first: which task track the ref belongs
to, where its requirements live, the branch convention, and how the work is
verified. Nothing below repeats it.

---

## Command Execution Instructions

When this command is invoked, follow these steps:

### Step 1: Extract Task Number

1. **If user provided task number** (e.g., `/plan:create rec-36`):
   - Extract the REC-XX identifier
   - Normalize to uppercase for Linear API (e.g., "rec-36" -> "REC-36")
   - Keep lowercase for file names (e.g., "rec-36")
   - Proceed to Step 2

2. **If no task number provided** (e.g., `/plan:create`):
   - Ask user: "Which Linear task do you want to create a plan for? (e.g., REC-36)"
   - Wait for response
   - Extract and normalize the task number
   - Proceed to Step 2

### Step 2: Fetch Linear Task Details

**Use Linear MCP to get task information**:

```
mcp__linear-server__get_issue(id="REC-XX")
```

**Extract from response**:
- `title`: Task title
- `description`: Full task description
- `state.name`: Current status
- `labels`: Any labels/tags

**Also fetch comments** for additional context:

```
mcp__linear-server__list_comments(issueId="REC-XX")
```

### Step 3: Check for Design Document

1. Search for design document: `docs/designs/rec-XX-*.md`
2. Use glob pattern: `docs/designs/rec-XX-*.md`

**If design document found**:
- Extract full filename (e.g., `rec-36-websocket-handler.md`)
- Read design document for detailed context
- Proceed to **Step 4A: Design Doc Mode**

**If design document NOT found**:
- Display message:

```
DESIGN DOCUMENT CHECK: Not found

No design document exists for REC-XX.

You can:
1. [create-design] - Create design document first (/design-doc:create rec-XX)
2. [proceed] - Proceed directly to planning (recommended for simpler tasks)
3. [cancel] - Exit command

Your choice:
```

- If **create-design**: Exit and suggest `/design-doc:create rec-XX`
- If **proceed**: Continue to **Step 4B: Direct Mode**
- If **cancel**: Exit command

### Step 4A: Design Doc Mode (Parse Existing Design)

**Read the design document** and extract:

1. **Summary/Overview**: High-level objective
2. **Architecture/Components**: Key components and their relationships
3. **Implementation Steps/Tasks**: Step-by-step tasks
4. **Acceptance Criteria**: Success metrics and validation steps
5. **Dependencies**: Prerequisites and related modules

**Cross-reference with Architecture Document** (if exists):

Read `docs/ARCHITECTURE.md` or `docs/adr/` to understand:
- Overall system architecture
- Design patterns and conventions
- Integration points

**Parse into actionable tasks**:

- Focus on concrete implementation steps
- Group by logical component or module
- Include validation tasks for each component
- Include integration with dependent modules

**Example transformation**:

```
Design Doc Section: "WebSocket Handler"
Content: "Create WebSocket support with connection management..."

Plan Task:
- [ ] Implement WebSocket handler module
  - [ ] Create connection manager
  - [ ] Implement message parsing
  - [ ] Add error handling
  - [ ] Write unit tests
```

**Proceed to Step 5** (Generate Plan File)

### Step 4B: Direct Mode (No Design Doc)

**Use Linear task information** gathered from Step 2:

**Analyze task title and description** to determine:
- Primary component or module
- Scope (new feature, modification, fix)
- Dependencies on other modules

**Read Architecture Document** (if exists):

Read `docs/ARCHITECTURE.md` or `docs/adr/` to understand:
- Where this component fits in the architecture
- Related modules and dependencies
- Configuration patterns

**Generate basic plan structure**:

```markdown
## Tasks

### Phase 1: Prerequisites & Setup
- [ ] [Extracted from dependencies]

### Phase 2: Core Implementation
- [ ] [Derived from task description and architecture]

### Phase 3: Testing & Validation
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual testing

### Phase 4: Finalization
- [ ] Create PR
```

**Proceed to Step 5**

### Step 5: Generate Plan File

**Determine filename**:
- If design doc exists: Use same base name (e.g., `rec-36-websocket-handler.md`)
- If direct mode: Generate from task title (e.g., `rec-36-cli-parser.md`)

**Create plan file**: `docs/plan/rec-XX-[description].md`

**Required format**:

```markdown
# REC-XX Implementation Plan: [Title]

**Linear Task**: https://linear.app/cloud-ai/issue/REC-XX
**Design Document**: docs/designs/rec-XX-[description].md (or "Direct mode - no design doc")
**Architecture Reference**: docs/adr/ (if exists)
**Created**: [Current Date]
**Overall Progress**: 0% (0/[total] tasks completed)

---

## Acceptance Criteria

Carried through verbatim from the design document (or the task file). These are
commands with expected results, not descriptions - `/plan:implement` runs them
at the phase boundary and the validation gate runs them again as Layer 1. A
criterion nobody can run is a bug here, not something to reword later.

- [ ] [Criterion 1 — command, and what it must print or exit]
- [ ] [Criterion 2]

---

## Architecture Context

[Brief summary of how this task fits into the system architecture]

---

## Tasks

### Phase 1: [Phase Name]

- [ ] Task 1: [Clear, actionable description]
  - [ ] Subtask 1.1: [Specific action with file path]
  - [ ] Subtask 1.2: [Specific action]

- [ ] Task 2: [Clear, actionable description]
  - [ ] Subtask 2.1: [Specific action]

### Phase 2: [Phase Name]

- [ ] Task 3: [Clear, actionable description]
  - [ ] Subtask 3.1: [Specific action]
  - [ ] Subtask 3.2: [Specific action]
  - [ ] Subtask 3.3: [Specific action]

[... additional phases based on design doc or task scope ...]

### Phase N: Testing & Validation

- [ ] Run the full gate: `scripts/gate.sh --task <task-id>`
- [ ] Run every Acceptance Criterion above and paste what it printed
- [ ] Manual verification of anything the criteria cannot express

### Phase N+1: Finalization

- [ ] Create PR with conventional commit message
  - [ ] Verify all commits follow format: type(REC-XX): description
  - [ ] Push branch: `git push origin feat/rec-XX-short-desc`
  - [ ] Create PR: `gh pr create --title "feat(REC-XX): [description]" --body "[PR body]"`
  - [ ] Link PR to Linear task REC-XX
  - [ ] Request review

---

## Module Structure

[List of modules that will be created or modified]

- `src/[module]/` - [Description]
- `tests/[module]/` - [Test files]

---

## Status Indicators

- `[ ]` = To do
- `[~]` = In progress
- `[x]` = Done
- `[!]` = Blocked (needs manual intervention)

**To update progress**: Edit this file and change checkboxes. The overall percentage will be recalculated based on completed tasks.

---

## Notes

- Keep tasks modular and minimal
- Each task should be independently testable
- Follow existing patterns in codebase
- Reference architecture doc for design decisions
- Mark tasks `[~]` when starting, `[x]` when complete
```

**Formatting Rules** (CRITICAL):

- **NO EMOJIS**: Use `[ ]`, `[~]`, `[x]` only
- Use clear, concise language
- Each task = 1-2 sentences max
- Include file paths where applicable
- Group related subtasks under parent tasks
- Calculate total tasks by counting all `[ ]` checkboxes
- **ALWAYS include Testing & Validation phase**
- **ALWAYS include Finalization phase** with PR creation task

### Step 6: Post Plan Summary to Linear

**Use Linear MCP to create comment**:

```
mcp__linear-server__save_comment(
  issueId="REC-XX",
  body="## Implementation Plan Created

A detailed implementation plan has been generated for this task.

**Plan File**: `docs/plan/rec-XX-[description].md`
**Mode**: [From design document / Direct from Linear task]

**Total Tasks**: [X tasks]
**Current Progress**: 0% (plan just created)

**Key Phases**:
- Phase 1: [Name] ([Y] tasks)
- Phase 2: [Name] ([Z] tasks)

**Modules**:
- [List modules to be modified]

Review the plan file for complete task breakdown and acceptance criteria."
)
```

### Step 7: Git Branch Management

**Check current branch**:

```bash
git rev-parse --abbrev-ref HEAD
```

**If on main**: Create feature branch

```bash
git checkout -b feat/rec-XX-[short-description]
```

**Branch naming format**: `{prefix}/rec-<number>-<short-desc>` (prefix: feat, fix, chore; 2-3 words max)

### Step 8: Confirm to User

**Output to user**:

```
SUCCESS: Implementation plan created!

File: docs/plan/rec-XX-[description].md
Branch: feat/rec-XX-[description]
Linear: Comment posted to REC-XX
Mode: [Design doc / Direct]

Tasks: [X] total

Next steps:
1. Review the plan file: docs/plan/rec-XX-[description].md
2. Start implementation: /plan:implement rec-XX
3. Update checkboxes as work progresses
```

---

## Special Cases

### Case 1: docs/plan/ folder doesn't exist

- Create folder automatically: `mkdir -p docs/plan`

### Case 2: Plan file already exists

```
Plan file already exists: docs/plan/rec-XX-[description].md

Options:
1. [overwrite] - Regenerate and overwrite
2. [open] - View existing plan (exit command)
3. [cancel] - Exit without changes

Your choice:
```

### Case 3: Task has minimal description

```
WARNING: Linear task REC-XX has minimal description

The plan will be based on the task title only. Consider:
1. [continue] - Create basic plan (can be refined later)
2. [cancel] - Exit and add more detail to Linear first

Your choice:
```

If continue: Generate basic template with task title, mark for refinement.

### Case 4: User provides invalid task number

- Validate format: REC-[number] or rec-[number]
- If invalid: Ask user to provide correct format

### Case 5: Multiple design docs match

- List all matching files
- Ask user to select the correct one

---

## Commit Message Types

| Task Type | Commit Type | Example |
|-----------|-------------|---------|
| New feature | `feat(REC-XX):` | `feat(REC-10): add WebSocket handler` |
| Bug fix | `fix(REC-XX):` | `fix(REC-15): resolve connection leak` |
| Refactoring | `refactor(REC-XX):` | `refactor(REC-20): simplify parser` |
| Documentation | `docs(REC-XX):` | `docs(REC-10): add API documentation` |
| Tests | `test(REC-XX):` | `test(REC-10): add unit tests` |
