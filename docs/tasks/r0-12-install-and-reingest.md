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
- [ ] Run representative searches and compare against the old installation

## Acceptance criteria

- [ ] `recol --version` prints `recol 0.7.0`
- [ ] `recol status` reports a raw message count greater than or equal to the R0-11 inventory
- [ ] `recol status` reports the database path under `~/.recol`, not `~/.remem`
- [ ] Three representative searches run with `--json` each return at least one result with non-empty `.results[].content`
- [ ] The same three queries against the old installation return comparable results
- [ ] `~/.remem` is byte-identical afterwards, verified as in R0-11
