# /pr:review - Handle PR Review Feedback

**Purpose**: Check for PR review comments, analyze feedback, make necessary changes, and respond to reviewers. Automates the review feedback cycle.

**Usage**:
- `/pr:review REC-XX` - Check and address reviews for specific task
- `/pr:review` - Interactive mode (detects from branch)

---

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    PR Review Cycle                              │
├─────────────────────────────────────────────────────────────────┤
│  1. Fetch PR reviews and comments (with pagination)             │
│  2. Analyze feedback (blocking vs suggestions)                  │
│  3. Detect stale comments (line changed since comment)          │
│  4. Make code changes to address feedback                       │
│  5. Commit changes with descriptive message                     │
│  6. Push to branch (BEFORE replying)                            │
│  7. Reply to EVERY comment (MANDATORY - track N/N)              │
│  8. Repeat if new comments arrive                               │
└─────────────────────────────────────────────────────────────────┘
```

### MANDATORY: Reply to Every Comment

**Every review comment MUST receive a reply.** This is not optional.
No comment may be left without a response - whether the fix was applied, declined with rationale, or acknowledged. The PR review is not complete until all comments have replies posted via the GitHub API.

| Decision | Required Reply |
|----------|---------------|
| Fixed | "Fixed in [SHA]. [what changed]" |
| Declined | "Intentionally kept as-is: [rationale]" |
| Question answered | "[explanation]. [reference to design doc if relevant]" |
| Deferred | "Tracked as follow-up in [task/issue]. [reason for deferral]" |

Two reviewers need a specific reply shape or they ignore the reply:

| Reviewer | Requirement |
|----------|-------------|
| `gemini-code-assist` | Reply MUST end with `/gemini review` on its own line |
| Qodo (`*qodo*[bot]`) | Reply MUST start with `@qodo` - Qodo only acts on messages that address it, including follow-ups in a thread it already replied to |

---

## Command Execution Instructions

### Step 1: Extract Task and PR Info

1. **Get task number** from argument or branch name
2. **Find PR number**:

```bash
gh pr list --head "feat/rec-XX-description" --json number,url,state
```

**If no PR found**:
```
ERROR: No PR found for REC-XX

Expected PR from branch: feat/rec-XX-*

Create one first: /pr:create REC-XX
```
Exit command.

### Step 2: Fetch PR Status

```bash
gh pr view [number] --json state,reviews,reviewDecision,comments,mergeable
```

Extract:
- `state`: open, closed, merged
- `reviews`: List of reviews with state (APPROVED, CHANGES_REQUESTED, COMMENTED)
- `reviewDecision`: Overall decision
- `comments`: General PR comments
- `mergeable`: Whether PR can be merged

**If PR is merged**:
```
PR #[number] is already merged.

Merged at: [timestamp]

No review action needed.
```
Exit command.

### Step 3: Fetch Review Comments

**Use `--paginate` on all gh api calls** to ensure no comments are missed on PRs with many reviews (default page size is 30).

```bash
# Get review comments (inline code comments) - paginated
gh api repos/{owner}/{repo}/pulls/[number]/comments --paginate \
  --jq '.[] | {id, path, line, original_line, body, user: .user.login, created_at, commit_id: .original_commit_id}'

# Get review threads - paginated
gh api repos/{owner}/{repo}/pulls/[number]/reviews --paginate \
  --jq '.[] | {id, state, body, user: .user.login}'

# Get issue comments (general discussion)
gh pr view [number] --json comments --jq '.comments[] | {id, body, author: .author.login}'
```

**Note**: The `commit_id` and `original_line` fields are used for stale comment detection in Step 4.5.

**Do not stop at inline comments.** Qodo reports most findings inside a single PR-level comment that it rewrites on every push, and inline comments only for findings above the configured severity threshold. Fetching only `/pulls/[number]/comments` silently drops everything below that threshold. Always fetch the PR-level comments as well:

```bash
gh api repos/{owner}/{repo}/issues/[number]/comments --paginate \
  --jq '.[] | {id, user: .user.login, updated_at, body}'
```

**Match bot reviewers by pattern, not by fixed login.** The Qodo app has shipped under several identities: `qodo-ai[bot]` on current installs, `qodo-merge-pro[bot]` and `codiumai-pr-agent-pro[bot]` on older ones. Resolve the login once for display:

```bash
QODO_BOT=$( { gh api repos/{owner}/{repo}/pulls/[number]/comments --paginate --jq '.[].user.login';
              gh api repos/{owner}/{repo}/issues/[number]/comments --paginate --jq '.[].user.login';
            } | grep -i qodo | sort -u | head -1 )
```

If `QODO_BOT` is empty, Qodo has not commented on this PR yet - do not fabricate its findings. Note that a self-hosted PR-Agent posts under the workflow token as `github-actions[bot]` and will not match this pattern.

`gh api` has no `--arg` flag, so filters below match the login by regex rather than substituting `$QODO_BOT` into jq.

### Step 4: Categorize Feedback

Group comments by type:

| Category | Priority | Action Required |
|----------|----------|-----------------|
| `CHANGES_REQUESTED` | High | Must address before merge |
| `COMMENTED` (blocking) | Medium | Should address |
| `COMMENTED` (suggestion) | Low | Optional, acknowledge |
| `APPROVED` | None | No action needed |

**Identify blocking feedback**:
- Explicit change requests
- Questions about implementation
- Security concerns
- Bug reports

**Identify non-blocking**:
- Style suggestions
- "Nice to have" improvements
- Positive feedback

### Step 4.5: Detect Stale Comments

For each inline comment, check if the referenced code has changed since the comment was posted:

1. The comment's `original_commit_id` tells you what commit the reviewer saw
2. Compare the file at that commit vs HEAD:
   ```bash
   git diff [original_commit_id]..HEAD -- [file_path]
   ```
3. If the diff includes changes around the commented line (within 5 lines), flag the comment as **potentially stale**

**Stale comments are presented to the user but marked clearly:**
```
[STALE?] @reviewer on src/backend/retry.rs:45
  "Consider adding jitter to retry delay"
  Note: Lines 40-50 of this file changed in commit abc1234 after this comment.
```

The user decides whether stale comments still need action. Do not auto-skip them.

### Step 5: Display Review Summary

```
========================================
PR REVIEW STATUS: REC-XX
========================================

PR #[number]: [title]
State: Open
Mergeable: Yes/No

Reviews:
  - @reviewer1: APPROVED
  - @reviewer2: CHANGES_REQUESTED

Overall Decision: [APPROVED / CHANGES_REQUESTED / PENDING]

Comments to Address: [count]

---

BLOCKING FEEDBACK:

1. @reviewer2 on src/websocket/handler.rs:45
   "Consider using async/await pattern here"
   Status: Unresolved

2. @reviewer2 general comment
   "Please add documentation for the public API"
   Status: Unresolved

---

SUGGESTIONS (optional):

1. @reviewer1 on src/websocket/parser.rs:12
   "Consider adding validation for input"
   Status: Unresolved

---

Options:
1. [address] - Address blocking feedback
2. [address-all] - Address all feedback including suggestions
3. [skip] - Skip for now
4. [details] - Show full comment details

Your choice:
```

### Step 6: Address Feedback

For each piece of blocking feedback:

#### 6.1: Analyze the Comment

Read the comment and:
1. Identify the file and line referenced
2. Understand the requested change
3. Read surrounding code for context
4. Determine the fix

#### 6.2: Make Code Changes

Use appropriate tools to implement the fix:

```bash
# Read the file
Read tool: [file path]

# Make changes
Edit tool: [modifications]

# Validate
cargo build && cargo test
```

#### 6.3: Track Changes Made

Keep a list of changes for commit message:
- `[file]: [change description]`

### Step 7: Create Review Response Commit

After addressing feedback, commit with descriptive message:

```bash
git add [modified files]
git commit -m "$(cat <<'EOF'
fix(REC-XX): address PR review feedback

Changes:
- src/websocket/handler.rs: Use async/await pattern
- src/websocket/mod.rs: Add public API documentation

Resolves review comments from @reviewer2

Related: PR #[number]
EOF
)"
```

### Step 8: Push Changes

Push BEFORE replying so the commit SHA is visible on GitHub when reviewers read your replies.

```bash
git push origin feat/rec-XX-description
```

### Step 9: Reply to EVERY Comment (MANDATORY)

**This step is REQUIRED. Do not skip it. Do not proceed to Step 10 until every comment has a reply.**

For EACH comment (fixed, declined, or question), post a reply via the GitHub API:

```bash
# Reply to a review comment
gh api repos/{owner}/{repo}/pulls/[number]/comments/[comment_id]/replies \
  -X POST -f body="Fixed in [commit SHA]. [Brief explanation of change]"
```

**Rules**:
1. Every comment gets a reply - no exceptions
2. Reference the commit SHA that contains the fix
3. If declining a suggestion, explain why (reference design docs, ADRs, or project constraints)
4. For `gemini-code-assist` comments: every reply MUST end with `/gemini review` on its own line
5. For Qodo comments: every reply MUST start with `@qodo`
6. For `copilot-pull-request-reviewer` comments: reply with fix details (no special trigger needed)
7. Qodo findings that appear only in the persistent summary comment have no thread to reply into. Answer them in one PR-level comment (Step 9b), not by inventing comment IDs
8. Track reply count - the final summary must show `Replies Posted: N/N`

**Reply templates by reviewer type**:

| Reviewer | Decision | Reply Template |
|----------|----------|----------------|
| Human | Bug fix | "Fixed in abc1234. Good catch!" |
| Human | Declined | "Intentionally kept as-is: [rationale]. Happy to discuss." |
| `gemini-code-assist` | Fixed | "Fixed in abc1234. [details]\n\n/gemini review" |
| `gemini-code-assist` | Declined | "Kept as-is: [reason]\n\n/gemini review" |
| Qodo | Fixed | "@qodo Fixed in abc1234. [details]" |
| Qodo | Declined | "@qodo Intentional: [rationale]. Please dismiss this finding." |
| `copilot-pull-request-reviewer` | Fixed | "Fixed in abc1234. [details]" |
| `copilot-pull-request-reviewer` | Declined | "Intentionally kept as-is: [rationale]" |

### Step 9b: Answer Summary-Only Qodo Findings

Findings below `inline_comments_severity_threshold` exist only inside Qodo's persistent comment. Post one PR-level comment covering all of them:

```bash
gh pr comment [number] --body "$(cat <<'EOF'
@qodo Addressed the findings from the latest review in abc1234.

- Requirement gap on retention classification: fixed, the classifier now fails closed.
- Informational finding on naming: kept as-is, the name matches the existing `SearchWeights` convention.

Please re-check.
EOF
)"
```

Qodo re-reviews on push when `handle_push_trigger` is enabled (see `.pr_agent.toml` at the repo root), so this comment is for the audit trail and for dismissals - it is not what triggers re-validation.

**Batch replies** (for multiple comments):

```bash
COMMIT_SHA=$(git rev-parse --short HEAD)
COMMENTS=(
  "COMMENT_ID_1|Fixed: description of change"
  "COMMENT_ID_2|Declined: rationale for keeping as-is"
)

for item in "${COMMENTS[@]}"; do
  ID="${item%%|*}"
  MSG="${item#*|}"
  gh api repos/{owner}/{repo}/pulls/[number]/comments/${ID}/replies \
    -X POST -f body="${MSG} (${COMMIT_SHA})"
done
```

Per-reviewer adjustments to the loop above:

- `gemini-code-assist`: append `/gemini review` to each reply body
- Qodo: prepend `@qodo ` to each reply body

### Step 10: Update Workflow State (if exists)

```yaml
phases:
  pr:
    reviews_addressed: [increment count]

history:
  - timestamp: [ISO timestamp]
    action: review_addressed
    phase: pr
    details: "Addressed [count] review comments, pushed [commit SHA]"
```

### Step 11: Re-check Review Status

After pushing, check if new comments appeared:

```bash
gh pr view [number] --json reviews,reviewDecision
```

**If new changes requested**:
```
New feedback received after your push.

[New comments]

Would you like to address these? (yes/no)
```

**If approved**:
```
SUCCESS: PR is now approved!

All reviewers have approved.
Ready to merge.

Next steps:
1. Merge: gh pr merge [number] --squash
2. Or continue with orchestrator: /task:orchestrate REC-XX
```

### Step 12: Update Linear

Post update to Linear:

```
mcp__linear-server__save_comment(
  issueId="REC-XX",
  body="## PR Review Update

**PR**: #[number]
**Status**: [Addressed feedback / Approved]

**Changes Made**:
- [Change 1]
- [Change 2]

**Commits**: [SHA]

**Review Status**:
- @reviewer1: Approved
- @reviewer2: [Updated status]"
)
```

### Step 13: Confirm to User

**GATE**: Do not display this summary until ALL comments have replies posted.
If any comment is missing a reply, go back to Step 9 and post it.

```
========================================
REVIEW FEEDBACK ADDRESSED
========================================

PR #[number]: [title]

Changes Made:
- [file1]: [change]
- [file2]: [change]

Commits: [count]
Pushed: Yes

Replies Posted: [N/N] (MUST be N/N - all comments replied to)
- Comment [id]: [fixed/declined/answered] (@reviewer)
- Comment [id]: [fixed/declined/answered] (@gemini-code-assist, with /gemini review)
- Comment [id]: [fixed/declined/answered] (@qodo-ai[bot], reply starts with @qodo)
- Comment [id]: [fixed/declined/answered] (@copilot-pull-request-reviewer)
- ...

Qodo summary-only findings: [count] answered in PR comment [id]

Stale Comments: [count skipped with user approval]

Review Status:
- @reviewer1: APPROVED
- @reviewer2: CHANGES_REQUESTED -> [pending re-review]

Next steps:
1. Wait for re-review
2. Run /pr:review REC-XX again if needed
3. After approval: /task:orchestrate REC-XX
```

---

## Handling Different Feedback Types

### Type 1: Code Change Request

```markdown
Reviewer: "Use async/await instead of callbacks"
File: src/websocket/handler.rs:45

Action:
1. Read src/websocket/handler.rs
2. Find line 45
3. Refactor to async/await
4. Commit and reply
```

### Type 2: Missing Functionality

```markdown
Reviewer: "Please add input validation"

Action:
1. Identify the relevant function
2. Add validation logic
3. Add tests for validation
4. Commit and reply
```

### Type 3: Documentation Request

```markdown
Reviewer: "Add usage examples to the module documentation"

Action:
1. Find or create doc comments
2. Add usage examples
3. Commit and reply
```

### Type 4: Question (No Code Change)

```markdown
Reviewer: "Why did you choose this approach?"

Action:
1. Reply with explanation
2. Reference design doc if applicable
3. No code change needed
```

### Type 5: Suggestion (Optional)

```markdown
Reviewer: "Nice to have: could add logging here"

Action:
1. Evaluate effort vs value
2. If quick: implement and reply
3. If complex: reply explaining decision to defer
```

---

## Batch Processing

When multiple comments exist:

1. **Group by file**: Address all comments on same file together
2. **Order by priority**: Blocking first, then suggestions
3. **Single commit per file group**: Avoid many small commits
4. **Batch replies**: Reply to all addressed comments

Example commit for batch:

```
fix(REC-XX): address PR review feedback (batch)

src/websocket/handler.rs:
- Line 45: Use async/await pattern
- Line 67: Add error context

src/websocket/parser.rs:
- Add input validation
- Add documentation

Resolves: 4 review comments from @reviewer2
```

---

## Special Cases

### Case 1: Conflicting Feedback

When two reviewers give conflicting feedback:

```
CONFLICT DETECTED: Reviewers disagree

@reviewer1: "Use sync approach for simplicity"
@reviewer2: "Use async for performance"

Please decide:
1. Follow @reviewer1's suggestion
2. Follow @reviewer2's suggestion
3. Find a compromise
4. Discuss in PR comments

Your choice:
```

### Case 2: Feedback Requires Design Change

```
SIGNIFICANT CHANGE REQUESTED

@reviewer1: "This should use a completely different architecture"

This feedback suggests changes beyond implementation fixes.

Options:
1. [discuss] - Comment asking for clarification
2. [update-design] - Revisit design document
3. [escalate] - Tag project lead for decision
4. [implement] - Try to implement anyway

Your choice:
```

### Case 3: Stale Comments

Stale comments are now detected automatically in Step 4.5. When a comment references code that has changed since the comment was posted, it is flagged with `[STALE?]` in the review summary.

The user decides how to handle stale comments:
- **Already addressed**: Reply explaining the change resolves the concern
- **Still relevant**: Address as normal
- **No longer applicable**: Reply noting the code has been restructured

### Case 4: All Approved

```
SUCCESS: All reviews approved!

No action needed.

PR is ready to merge.

Options:
1. [merge] - Merge the PR
2. [wait] - Wait for more reviews
3. [exit] - Exit (merge manually)

Your choice:
```

---

## AI Code Reviewers

Steps 3 through 9 are the whole cycle for every bot: fetch, categorize, fix,
commit, push, reply. The bots differ in three things only - where their findings
live, how you address them, and what makes them re-check. Everything below is
those differences. Nothing here repeats the cycle.

### Reviewer comparison

| Aspect | Qodo | gemini-code-assist | copilot-pull-request-reviewer |
|--------|------|--------------------|-------------------------------|
| Severity | Priority groups (Action Required / Review Recommended / Informational) | `**Severity**: high/medium/low` | None - treat as medium |
| Where findings live | One persistent PR comment + inline above threshold | Inline only | Inline only |
| Re-validation trigger | Automatic on push, or `/agentic_review` | `/gemini review` in reply | Automatic on push |
| Reply requirement | Must start with `@qodo` | Must end with `/gemini review` | None |
| Resolution marker | Strikethrough on next run | Thread resolution | Thread resolution |
| Repo config | `.pr_agent.toml` on default branch | `.gemini/config.yaml` | Repo settings |

### Fetching

Inline comments come from the same endpoint for all three; only the login filter
changes. Match Qodo by regex - the app has shipped as `qodo-ai[bot]`,
`qodo-merge-pro[bot]`, and `codiumai-pr-agent-pro[bot]` across migrations, and
`gh api` supports `--jq` but not jq's `--arg`, so a shell variable cannot be
interpolated into the filter safely.

```bash
PR=[number]

# Qodo - inline
gh api repos/{owner}/{repo}/pulls/$PR/comments --paginate \
  --jq '.[] | select(.user.login | ascii_downcase | test("qodo")) | {id, path, line, body}'

# Qodo - the persistent summary comment, which holds findings that have no thread
gh api repos/{owner}/{repo}/issues/$PR/comments --paginate \
  --jq '.[] | select(.user.login | ascii_downcase | test("qodo")) | {id, updated_at, body}'

# gemini-code-assist
gh api repos/{owner}/{repo}/pulls/$PR/comments --paginate \
  --jq '.[] | select(.user.login == "gemini-code-assist") | {id, path, line, body}'

# copilot
gh api repos/{owner}/{repo}/pulls/$PR/comments --paginate \
  --jq '.[] | select(.user.login == "copilot-pull-request-reviewer") | {id, path, line, body}'
```

**Fetching only `pulls/$PR/comments` silently drops findings.** Qodo publishes
inline comments only at or above `inline_comments_severity_threshold`; everything
below it exists in the summary comment alone, with no signal that you missed it.

---

### Qodo

Three deviations break the default workflow if ignored:

1. **Findings live in one persistent comment.** Qodo rewrites a single PR-level
   comment on every push rather than posting a new one.
2. **Replies must address Qodo explicitly.** A reply that does not start with
   `@qodo` is not read, even inside a thread Qodo itself opened.
3. **Resolution is inferred from the code, not the reply.** Pushing a fix makes
   Qodo strike the finding through on its next run. The reply is for dismissals
   and for the audit trail.

Repository configuration lives in `.pr_agent.toml` at the root of the default
branch, and applies only to PRs opened after that file lands there.

**Reading the summary comment.** It is long and mostly collapsed HTML: read it
for the finding list, do not paste it back to the user. Findings are grouped by
priority, then labelled with a quality dimension.

| Priority group | Severity | Maps to | Action |
|----------------|----------|---------|--------|
| Action Required | 3 | Blocking | Must fix before merge |
| Review Recommended | 2 | Should fix | Fix or decline with rationale |
| Informational | 1 | Optional | Acknowledge, fix if cheap |

Finding categories: **Bugs**, **Rule violations** (from `AGENTS.md` / `CLAUDE.md`,
which Qodo imports as rules), **Requirement gaps** (from the linked ticket),
**Cross-repo conflicts**, **Skill insights**. Quality labels: `Correctness`,
`Security`, `Reliability`, `Performance`, `Observability`.

Two markers matter on a re-read after pushing:

- **⭐️ New** - raised by the latest run. Address these.
- **Struck through** - Qodo considers it resolved. Do not re-fix, do not reply.

A **Previous review results** section holds earlier runs. Ignore it unless
auditing history; those findings are superseded by the current list.

**A `Rule violation` is not a style nit.** It means the diff contradicts a rule
Qodo imported from this repo's own `AGENTS.md` or `CLAUDE.md`. Treat it as
blocking whatever priority group it landed in, or fix the rule file if the rule
is genuinely wrong. Do not decline it as a matter of taste.

**Dismissing and asking:**

```bash
# Decline a finding, in its own thread
gh api repos/{owner}/{repo}/pulls/$PR/comments/[comment_id]/replies \
  -X POST -f body="@qodo Intentional: the allocation is per-request and bounded by MAX_BATCH. Please dismiss this finding."

# Ask about a finding you do not understand
gh pr comment $PR --body "@qodo Which rule does finding 3 come from, and where is it defined?"
```

Do **not** use `@qodo fix ...` inside this workflow: it opens a *separate PR*
with proposed changes rather than committing to the current branch, fragmenting
one change across two PRs. Fix the code directly.

**Manual re-review.** With `handle_push_trigger = true` no trigger is needed.
Otherwise `gh pr comment $PR --body "/agentic_review"`; Qodo acknowledges with
👀. Also supported: `/agentic_describe`, `/ask`, `/config` (prints the effective
configuration, useful for debugging why a finding did or did not appear),
`/generate_labels`, `/checks`. `/review` and `/improve` are legacy Qodo Merge v1
commands and do nothing on a current install.

---

### gemini-code-assist

Parse `**Severity**: high/medium/low` from the comment body; a comment without
one is `medium`.

| Severity | Action |
|----------|--------|
| `high` | Address before merge |
| `medium` | Strongly recommended |
| `low` | Nice to have |

**Every reply must end with `/gemini review`.** That is what makes Gemini
re-read the updated files, check whether the change addresses its concern, and
either resolve the thread or post follow-up. A reply without it leaves the
thread open forever.

```bash
COMMIT=$(git rev-parse --short HEAD)
gh api repos/{owner}/{repo}/pulls/$PR/comments/[comment_id]/replies \
  -X POST -f body="Fixed in ${COMMIT}. [what changed and why it addresses the finding]

/gemini review"
```

### copilot-pull-request-reviewer

No severity levels - treat everything as medium. No trigger suffix; it
re-reviews automatically on push. Otherwise identical to any other inline
comment.

---

### Review summary display

One format for all three. Fill `Reviewer` and the grouping from the table above -
priority groups for Qodo, severity for Gemini, a single group for copilot.

```
========================================
[REVIEWER] REVIEW: [task-id]
========================================

PR #[number]: [title]
Reviewer: [bot login]
Summary comment last updated: [timestamp, Qodo only]

Findings: [N] open ([M] struck through as resolved)

[GROUP - e.g. ACTION REQUIRED / HIGH PRIORITY]:
1. [inline #<id> | summary-only] <path>:<line>  [quality label]
   "<the finding, one line>"
   Status: Needs fix

[NEXT GROUP]:
2. ...

---

Options:
1. [address-all]      - Fix all findings
2. [address-blocking] - Highest group only
3. [details N]        - Show full finding N
4. [skip]             - Skip for now

Your choice:
```

Report `summary-only` findings explicitly. They have no thread to reply in, so
Step 9b answers them in one PR-level comment; leaving them out of this display is
how they get lost.

---

## Integration Notes

**Called by**: `/task:orchestrate` during PR phase

**Follows**: `/pr:create`

**Precedes**: Merge (via orchestrator or manual)

**Updates**:
- Code files (to address feedback)
- Git repository (commits)
- PR comments (replies)
- Linear task (status update)
- Workflow state file
