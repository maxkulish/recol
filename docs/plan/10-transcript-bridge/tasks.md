# R2 Task Plan: transcript-to-curation bridge

Spec packet: `product.md`, `tech.md`, this file.
Blocked on: R1 in `../01-roadmap.md`.

## Preconditions

Do not start until all three hold:

- R1 step 1 is done, so a failed extraction persists its raw output. Without it,
  every bridge failure is ambiguous between a bridge bug and a model bug.
- One extraction has completed successfully end to end, establishing a working
  model and reasoning configuration.
- The gold-set baseline is recorded, so bridge output can be compared against
  raw search rather than judged in isolation.

## Tasks

### T1 - Read the existing identity machinery

Read `src/ingest/session_identity.rs` and `src/session_rollup/raw_identity.rs`
before writing code. Both already map archived transcripts to identity, and the
mapping the bridge needs may exist. Output is a short note in this file
recording what is reusable and what is missing. No code.

### T2 - Decide the grouping unit

Choose whether one raw row becomes one captured event, or rows are grouped per
turn or per session. Settle it by experiment: hand-build both shapes for a
single real session, run extraction on each, and compare the memories. This
decision drives extraction quality more than anything else in the bridge, and
guessing it wastes the work that follows.

Record the choice and the evidence as an ADR in `docs/adr/`, since it will
outlive this work item.

### T3 - Identity mapping, with tests first

Implement the raw-row to `captured_events` mapping, including a stable derived
`event_id`. Tests before implementation, per `tech.md` section 3, and include
the deleted-worktree case in the first test rather than as a follow-up.

### T4 - Provenance

Establish how promoted events are distinguished from hook events, preferring an
existing column. If a new column is required, write the migration and check that
an upstream-built binary can still read the database.

### T5 - The command

`recol promote-transcripts` with `--project` required, plus `--since`,
`--until`, `--limit`, and `--dry-run`. Dry run reports event count and an
estimated token cost, states that the estimate is a lower bound, and writes
nothing.

### T6 - Idempotency

Verify the `ON CONFLICT(host_id, session_id, event_id)` path behaves for
promoted rows: same range twice, then an overlapping range, asserting stable
counts both times.

### T7 - Rollback

Deletion by provenance, removing promoted events and their downstream memories
without touching hook-captured data. Do this before the first large run, not
after it.

### T8 - Evaluate

Promote one real project with dense decision history. Run the ten-question gold
set. Record Recall@5, the rationale-not-summary judgement, and actual spend
against the dry-run estimate.

This task decides whether the fork's premise holds. Write the result up whether
it is good or bad.

## Parallel splits

T1 and T2 are investigation and can run concurrently.

T3 and T4 are both blocked on T1, and are independent of each other once it
lands.

T5 depends on T3 and T4. T6 and T7 depend on T5. T8 depends on everything.

## Verification

- `cargo test` green, with the new tests from T3, T6, T7 present.
- `cargo clippy -- -D warnings` clean.
- A promoted project produces curated memories that a query returns.
- Deleting by provenance leaves hook-captured data untouched, verified by row
  counts before and after.
- Gold-set result recorded in T8, compared against the raw-search baseline.

## Handoff notes

The measurement that matters is T8, and it is the only one that can invalidate
the fork. If promoted transcripts produce memories no better than raw search
hits, the bridge is not the missing piece and the problem is the extraction
prompt. In that case stop, write it up, and re-plan rather than tuning.
