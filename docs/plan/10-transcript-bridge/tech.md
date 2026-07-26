# R2 Tech Spec: transcript-to-curation bridge

Companion to `product.md`. Code paths verified against the fork at the time of
writing; re-check line numbers before relying on them.

## 1. Current code paths

**Ingestion.** `Commands::IngestSessions` in `src/cli/dispatch.rs` calls
`run_ingest_sessions_cli` in `src/cli/actions/ingest_sessions.rs`, which builds
scan roots from `default_scan_roots()` plus `--root` extras, opens the database,
and calls `run_ingest_sessions` in `src/ingest/sessions.rs`. That module
contains no reference to the AI layer, no HTTP client, no subprocess spawn, and
no queueing. It writes `raw_messages` rows and an `ingest_cursors` row.

**Raw archive.** `src/memory/raw_archive.rs` defines `SOURCE_TRANSCRIPT`,
`SOURCE_HOOK`, `SOURCE_MANUAL`, the `insert_raw_message` family, and
`search_raw_messages`. Rows carry `id`, `session_id`, `project`, `role`,
`content`, `source`, `branch`, `cwd`, `created_at_epoch`.

**Capture.** `src/db/capture.rs` writes `captured_events` with columns
`host_id`, `workspace_id`, `project_id`, `session_row_id`, `session_id`,
`turn_id`, `event_id`, `event_type`, `role`, `tool_name`, `content_text`,
`content_blob_id`, `content_hash`, `token_estimate`, `retention_class`,
`created_at_epoch`, `inserted_at_epoch`, `reference_time_epoch`. The insert is
`ON CONFLICT(host_id, session_id, event_id) DO UPDATE`, which is the existing
idempotency mechanism and should be the bridge's too.

**Extraction.** The worker claims tasks of kind `observation_extract`, calls the
configured AI profile, and parses with
`parse_observation_extract_response` in `src/observation_extract/response.rs`.

## 2. Design

The bridge is a new command that reads `raw_messages` rows with
`source = 'transcript'` and writes `captured_events` through the existing
capture path, so everything downstream is untouched.

```
recol promote-transcripts --project <path> [--since <t>] [--until <t>]
                          [--limit <n>] [--dry-run]
```

**Identity resolution is the hard part.** `captured_events` requires
`host_id`, `workspace_id`, `project_id`, and `session_row_id`, which the hook
path derives from a live session. The archive has `project`, `cwd`, `branch`,
and `session_id`. Two of these are already solved in the codebase and should be
reused rather than re-derived: `src/ingest/session_identity.rs` handles
transcript session identity, and `src/session_rollup/raw_identity.rs` already
queries `raw_messages` for `session_id` and `transcript_identity_id`. Read both
before writing anything; the mapping may already exist in a usable form.

**Event identity must be stable and derived, not generated.** The conflict key
is `(host_id, session_id, event_id)`. Derive `event_id` from the raw row -
`raw_messages.id`, or a content hash if row ids are not stable across a
re-ingest - so that re-running promotion updates rather than duplicates. This
is acceptance criterion 3 and it is a schema-level guarantee, not a check in the
command.

**Provenance.** Promoted events need to be distinguishable from hook events.
Prefer an existing column over a new one: `event_type` or `retention_class` may
already carry a suitable discriminator. Only add a column if neither does, and
if a column is added, a migration is required and upstream compatibility must be
considered.

**Content.** Hook events are single tool operations; transcript rows are whole
conversational turns. Decide explicitly whether one raw row becomes one event,
or whether a session's rows are grouped into one event per turn or per session.
This choice determines extraction quality more than any other decision here, and
it should be settled by running both against the gold set rather than argued.

**Bounding.** No wildcard project selection until R3 lands. `--project` is
required and takes one path. `--dry-run` reports event count and an estimated
token cost without writing or spending.

## 3. Test plan

Unit:

- Identity mapping from a raw row to a `captured_events` row, including a row
  whose `cwd` no longer exists on disk. The 193 ingest errors were all deleted
  worktrees, so this is the common case, not the edge case.
- `event_id` derivation is stable across two runs over identical input.
- Promotion of the same range twice produces the same row count.
- `--dry-run` writes nothing: assert row counts before and after are equal.

Integration:

- Promote a fixture project, run the worker, assert curated memories exist and
  carry promoted provenance.
- Promote a range, promote an overlapping range, assert no duplicate memories.
- Refuse to run without `--project`.

Evaluation, which is the test that matters:

- Promote one real project with dense decision history. Run the ten-question
  gold set. Compare against the raw-search baseline of roughly 6.5 of 10, and
  check the rationale-not-summary criterion by reading the memories.

## 4. Migration and rollback

If no new column is needed, there is no migration. If provenance requires one,
it must default in a way that leaves existing rows valid and must not break an
upstream-built binary reading the same database.

Rollback is deletion by provenance: every promoted event and its downstream
memories must be removable without touching hook-captured data. Verify this
before the first large run, not after.

## 5. Risks

**The identity mapping may not be clean.** `captured_events` was designed around
a live session with a host and workspace. If archived transcripts cannot produce
a coherent identity, the bridge may need a synthetic host, which has
consequences for retrieval scoping that need checking before committing to it.

**Extraction prompt mismatch.** See `product.md` section 7. The bridge could be
correct and the memories still poor, because the prompt expects tool events.
Distinguishing these two failure modes is why R1 must land first.

**Cost accounting is unreliable.** The one extraction attempted so far recorded
a text-length estimate rather than provider data, so a dry-run estimate built on
the same accounting will be optimistic. State the estimate as a lower bound.
