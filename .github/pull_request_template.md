## PR Type

- [ ] Implementation
- [ ] Bugfix
- [ ] Docs/process
- [ ] Release

## What

Brief description of changes.

## Why

Why is this change needed?

## Task

For `docs/tasks/` work, name the task and paste the gate verdict:

- Task:
- `scripts/gate.sh --task <id>` verdict:

The gate is a **local** referee; CI does not invoke it, so nothing blocks a
merge on it. It exits `0` on pass, `1` on failure, and `2` when a layer could
not run, which is never a pass.

CI covers the same ground for the compiler and test suite. What it does not
cover is the task's acceptance criteria: the gate prints them without running
them, so a PASS says nothing about whether they hold. List each criterion and
its actual output below.

- Acceptance criteria, with output:

## Test Plan

- [ ] `cargo fmt --check`, `cargo check`, `cargo test` pass
- [ ] Acceptance criteria verified, with output
- [ ] Tested manually where behavior is user-visible

## Merge Gate

- [ ] Required `check` is green on the final head
- [ ] Review findings resolved, or recorded with a reason
