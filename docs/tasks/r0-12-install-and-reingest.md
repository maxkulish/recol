# R0-12 - Install the renamed build and re-ingest

Type: **HITL** | Blocked by: R0-10, R0-11 | Blocks: R0-13
Phase: 3 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 3)

## Goal

A `recol` installation under the new data path holds an archive equivalent to
the old one and answers searches correctly, proven before anything is deleted.

## Context

This task is entirely additive. The old installation stays untouched, so a
failure here costs nothing but time. R0-13 is the irreversible step.

Re-ingestion reprocesses roughly 1,900 transcript files and 22,555 messages. It
costs wall-clock time but no model calls: `ingest-sessions` fills the raw
archive and does not feed the extraction pipeline. That separation is the
finding this whole project exists to fix, and it is what makes the corpus cheap
to rebuild.

Expect the new count to differ slightly from the inventory. Transcripts have
accumulated since the original ingest, so the new number should be **greater
than or equal to** the old, never less.

**Diagnose searches with `--json`**, reading `.results[].content`. The printed
output shows only the first line of each message as a preview, which previously
made four unrelated queries look like they returned identical wrong results.

## Scope

- [ ] `cargo install --path .` from the renamed tree
- [ ] A fresh cipher key stored under Keychain service `recol-cipher-key`
- [ ] Re-ingest under a fresh `RECOL_DATA_DIR`
- [ ] Run representative searches and compare against a restored copy of the
      R0-11 snapshot, never against the live `~/.remem`

## Acceptance criteria

- [ ] `recol --version` prints `recol 0.7.0`
- [ ] `recol status` reports a raw message count greater than or equal to the R0-11 inventory
- [ ] `recol status` reports the database path under `~/.recol`, not `~/.remem`
- [ ] Three representative searches run with `--json` each return at least one result with non-empty `.results[].content`
- [ ] The same three queries against the **restored R0-11 snapshot** return comparable results
- [ ] `~/.remem` is byte-identical afterwards: `shasum -a 256 -c` against the R0-11 baseline reports OK for every file, with none added or removed

## Do not query the live old installation

An earlier version of this task compared against `~/.remem` directly. That
contradicts the byte-identity criterion below it: `run_search` calls
`db::open_db()` at `src/cli/actions/query/search.rs:27`, and `open_db()` runs
`crate::migrate::run_migrations()` at `src/db/core.rs:127` against a
`journal_mode=WAL` store. Searching the original mutates it, and every command
also appends to `~/.remem/remem.log`.

Run the comparison against a restored copy of the R0-11 snapshot instead,
following `~/Backups/recol/2026-07-31/RESTORE.md`. The restore is already proven
byte-identical to the original, so it answers the same question without
touching the thing being preserved.

If a read-only inventory is ever wanted, `open_db_no_migrate()` at
`src/db/core.rs:133` and the path at `:165-168` are documented as never
creating, migrating, or repairing the store. Neither `status` nor `search` uses
them today.
