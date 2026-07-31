# R0-11 - Inventory and snapshot the existing installation (product)

Status: Current contract
Task: `docs/tasks/r0-11-inventory-and-snapshot.md`
Plan: `docs/plan/20-rename-and-release/tech.md` (Phase 3)

## Why this exists

R0 renames the project and moves the local installation from `~/.remem` to
`~/.recol`. Every task in that sequence is additive until R0-13, which deletes
the old data directory and the old Keychain entry. R0-11 is the task that makes
R0-13 safe to run.

The database holds no curated state. `status` reports Memories 0, Observations
0, Sessions 0, Candidates 0, Graph queue 0. The 22,555-message raw archive is
reproducible by re-running `ingest-sessions` against transcripts that are still
on disk, which is exactly what R0-12 does.

One thing is not reproducible. Extraction task id 1 shows as `Extract fail: 1`
and `Replay todo: 1`, came from synthetic session `manual-eval-1785099656`, and
is the target of R1 step 2, which replays it to classify the extraction failure
as configuration or structural. The CLI has no dump path for a single extraction
task: `--replay-range-id` replays, it does not export. So the snapshot is the
artifact, and R1 works by restoring it into a scratch data directory and
replaying there.

## Who consumes the output

| Consumer | Artifact it needs | What it does with it |
|---|---|---|
| R0-12 | Inventory counts | Asserts the re-ingested archive is not smaller than the old one |
| R0-13 | A restorable snapshot | Justifies deleting `~/.remem` and the old Keychain entry |
| R1 step 2 | A restorable snapshot | Restores it to a scratch data directory and replays extraction task 1 |

R1 runs after the old Keychain entry is gone. That is the constraint that shapes
the whole design: the snapshot must decrypt without anything that R0-13 deletes.

## Outcomes

1. **A baseline exists.** A counts inventory that R0-12 can be compared against,
   recorded with the exact JSON field paths it was read from, so a later reader
   can re-derive it rather than trust it.
2. **The irreplaceable row is recoverable.** An encrypted archive of the whole
   `~/.remem` directory, stored outside it, that has been proven to restore and
   open.
3. **The original is untouched.** `~/.remem` is byte-identical after the task,
   verified against a checksum baseline taken before anything ran.

## Non-goals

- Exporting extraction task 1 as a standalone file. No such command exists, and
  building one is not in scope for a backup task.
- Backing up anything outside `~/.remem`. The `.zshrc` wrapper is handled by
  R0-13; transcripts on disk are the input to R0-12, not state to preserve.
- Adding a reusable backup script to the repository. This runs once. R0-02 is
  removing scripts, not adding them.

## Success criteria

The task is done when all of the following are true, each by a command whose
output was recorded:

- [ ] `docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md` records raw message
      count, memories, observations, sessions, pending candidates, extract-fail
      count, replay-todo count, and schema version.
- [ ] The snapshot exists under `~/Backups/recol/2026-07-31/`, outside
      `~/.remem`, and is larger than 150 MiB (157286400 bytes).
- [ ] The snapshot decrypts, extracts, and every extracted file matches the
      pre-snapshot checksum baseline.
- [ ] The restored copy opens with no `REMEM_CIPHER_KEY` in the environment and
      no Keychain lookup, and reports `Extract fail: 1` and `Replay todo: 1`.
- [ ] `~/.remem` matches its pre-task checksum baseline, with no files added or
      removed.

## Corrections to the task file

Three statements in `docs/tasks/r0-11-inventory-and-snapshot.md` do not survive
contact with the code. They are corrected here, and the reasoning is in
`TECH.md`.

**The snapshot alone is not restorable.** There is no `.key` file in `~/.remem`.
`load_cipher_key()` at `src/db/crypto.rs:36` checks `REMEM_CIPHER_KEY`, then
`<data_dir>/.key`, and nothing else, and the key lives only in the macOS
Keychain under service `remem-cipher-key`, read by the `.zshrc` wrapper. R0-13
deletes that entry. An archive of `~/.remem` taken as described would become
unreadable ciphertext the moment R0-13 completes.

**Reading the inventory from the live installation breaks byte-identity.**
`remem status` reaches `open_db()` at `src/db/core.rs:127`, which runs
migrations, and the store is `journal_mode=WAL`. Any command against the live
directory writes to `remem.db` and appends to `remem.log`.

**"Restored counts identical to the inventory" is circular** once the inventory
is read from the restored copy. It is replaced by a stronger check: byte
equality between the restored tree and the pre-snapshot baseline. Byte equality
implies count equality; the reverse does not hold.

The task file also refers to `recol status` in its Context section. At R0-11
time the rename has not happened: R0-08 through R0-10 are Phase 2 and R0-11 is
Phase 3, but R0-11 has no blockers and the task README directs that it run
first. The binary is `remem` and the variable is `REMEM_DATA_DIR`.
