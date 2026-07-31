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

`remem status` reports Memories 0, Observations 0, Sessions 0, Candidates 0,
Graph queue 0. There is no curated state. The 22,555-message raw archive is
reproducible by re-running `ingest-sessions` against transcripts still on disk.

**Extraction task id 1 is not reproducible.** It shows as `Extract fail: 1` and
`Replay todo: 1`, came from synthetic session `manual-eval-1785099656`, and is
the exact target of R1 step 2, which replays it to classify the extraction
failure as configuration or structural.

**There is no export subcommand for an extraction task.** The CLI has no dump
path - `--replay-range-id` replays, it does not extract. So the encrypted
snapshot *is* the artifact, and R1 step 2 works by restoring the snapshot into a
scratch `REMEM_DATA_DIR` and replaying there. Do not plan around extracting a
single row.

**The snapshot must carry its own key.** There is no `.key` file in `~/.remem`.
`load_cipher_key()` at `src/db/crypto.rs:36` reads `REMEM_CIPHER_KEY`, then
`<data_dir>/.key`, and nothing else; the key lives only in Keychain service
`remem-cipher-key`, which R0-13 deletes. An archive of the directory alone
becomes unreadable ciphertext the moment R0-13 completes.

**Reading the inventory from the live installation mutates it.** `remem status`
reaches `open_db()` at `src/db/core.rs:127`, which runs migrations against a
`journal_mode=WAL` store, and any command appends to `~/.remem/remem.log`. The
inventory is therefore read from the restored copy, not the original.

At R0-11 time the rename has not happened. The binary is `remem` and the
variable is `REMEM_DATA_DIR`.

Full procedure: `docs/specs/r0-11-inventory-and-snapshot/TECH.md`.
Execution plan: `docs/plan/20-rename-and-release/r0-11-execution-plan.md`.

## Scope

- [ ] Cold checksum baseline of `~/.remem`, taken before anything else runs
- [ ] Encrypted archive of the whole `~/.remem` directory, carrying the
      SQLCipher key as a sibling file, stored outside `~/.remem`
- [ ] Archive passphrase in Keychain service `recol-snapshot-key`, which R0-13
      does not touch
- [ ] Prove the archive restores byte for byte and opens with no Keychain lookup
- [ ] Record a table-count inventory from the restored copy

## Acceptance criteria

- [ ] `docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md` records raw message
      count, memories, observations, sessions, pending candidates, extract-fail
      count, replay-todo count, and schema version, each with its JSON path
- [ ] The snapshot exists outside `~/.remem` and is larger than 150 MiB
- [ ] Restore test: unpack the snapshot to a scratch directory and
      `shasum -a 256 -c baseline.sha256` reports OK for every file, with no
      files added or removed
- [ ] The restored copy opens with `REMEM_CIPHER_KEY` unset and no Keychain
      lookup, using only the bundled `.key`, and reports `Extract fail: 1` and
      `Replay todo: 1`
- [ ] `~/.remem` matches its pre-task baseline: `shasum -a 256 -c` reports OK
      for every file and the file list is unchanged
