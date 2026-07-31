# R0-11 inventory - `~/.remem` as of 2026-07-31

Read from the restored snapshot, not from the live installation. `remem status`
runs migrations against a WAL store, so the original was never opened by the
binary. See `TECH.md` for why.

Source: `~/Backups/recol/2026-07-31/inventory.json`, produced by
`remem status --json` against the restored copy.

| Field | Value | JSON path |
|---|---|---|
| Binary version and supported schema | 0.6.27 (schema v73) | `.version` |
| Raw messages | 22555 | `.totals.raw_messages` |
| Memories | 0 | `.totals.memories` |
| Observations | 0 | `.totals.observations` |
| Sessions | 0 | `.totals.sessions` |
| Pending candidates | 0 | `.capture_pipeline.pending_candidates` |
| Graph queue | 0 | `.capture_pipeline.pending_graph_candidates` |
| Extract fail | 1 | `.capture_pipeline.extract_failed` |
| Replay todo | 1 | `.capture_pipeline.retryable_replay_ranges` |
| Database size (bytes) | 207863808 | `.database.size_bytes` |

## Schema

Applied migration version and SQLite `user_version`, from
`~/Backups/recol/2026-07-31/doctor.json`:

Schema [ok] migrations v73 (sqlite user_version 85, logical user_version 85, up to date)

## Snapshot

| | |
|---|---|
| Archive | `~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg` |
| Ciphertext SHA-256 | `508e69910df44640776773e92396a4198a28e486172476930b6734b7b8cba6fa` |
| Plaintext tar SHA-256 | `2e104be1d9a64e75b453a79d8183d4a31185d3fbb130d6b18eded57035ff9092` |
| Passphrase | Keychain service `recol-snapshot-key` |
| Restore instructions | `~/Backups/recol/2026-07-31/RESTORE.md` |

## What R0-12 compares against

`recol status` after re-ingest must report a raw message count **greater than or
equal to** the raw messages row above. Transcripts accumulate between the two
runs, so a larger number is expected and a smaller one is a failure.
