# R0-11 - Inventory and snapshot the existing installation

Type: **HITL** | Blocked by: none | Blocks: R0-12
Phase: 3 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 3)

## Goal

The one thing in `~/.remem` that cannot be rebuilt is recoverable, and there is
a baseline to verify the new installation against.

## Do this first

Nothing blocks it, and it is the only task that protects against every other
task going wrong. Run it before starting R0-01.

## Context

`recol status` reports Memories 0, Observations 0, Sessions 0, Candidates 0,
Graph queue 0. There is no curated state. The 22,555-message raw archive is
reproducible by re-running `ingest-sessions` against transcripts still on disk.

**Extraction task id 1 is not reproducible.** It shows as `Extract fail: 1` and
`Replay todo: 1`, came from synthetic session `manual-eval-1785099656`, and is
the exact target of R1 step 2, which replays it to classify the extraction
failure as configuration or structural.

**There is no export subcommand for an extraction task.** The CLI has no dump
path - `--replay-range-id` replays, it does not extract. So the encrypted
snapshot *is* the artifact, and R1 step 2 works by restoring the snapshot into a
scratch `RECOL_DATA_DIR` and replaying there. Do not plan around extracting a
single row.

`config.toml` records host `codex-cli`, model `gpt-5.6-luna`, reasoning `low`.
Trivially recreatable, but capture it anyway - it is 937 bytes.

Commands need `REMEM_CIPHER_KEY` in the environment. The `.zshrc` wrapper
supplies it interactively; a fresh agent shell does not.

## Scope

- [ ] Record a table-count inventory from `status`
- [ ] Encrypted archive of the whole `~/.remem` directory, stored outside it
- [ ] Prove the archive restores and opens

## Acceptance criteria

- [ ] An inventory file records at minimum: raw message count, memories,
      observations, sessions, candidates, extract-fail count, and schema version
- [ ] The snapshot exists outside `~/.remem` and is larger than 150 MB
- [ ] Restore test: unpack the snapshot to a scratch directory, point
      `REMEM_DATA_DIR` at it, and `remem status` reports counts **identical** to
      the inventory
- [ ] The restored copy shows `Extract fail: 1` and `Replay todo: 1`
- [ ] `~/.remem` is byte-identical afterwards: compare
      `find ~/.remem -type f -exec shasum {} +` before and after
