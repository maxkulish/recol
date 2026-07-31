# R0-11 Inventory and Snapshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a proven-restorable encrypted snapshot of `~/.remem` and a counts inventory, without the binary ever opening the live data directory.

**Architecture:** Seven tasks in strict order. Task 1 is documentation only. Tasks 2-7 operate on the real home directory and Keychain and must run in sequence, because each one's verification depends on the checksum baseline the previous one established. The live directory is treated as read-only from Task 2 onward; every read that would mutate it is performed against a disposable restored copy instead.

**Tech Stack:** zsh, BSD `tar`, `shasum`, `gpg` 2.x (`/opt/homebrew/bin/gpg`), `jq`, macOS `security`. No Rust changes. No new dependencies.

**Spec:** `docs/specs/r0-11-inventory-and-snapshot/PRODUCT.md` and `TECH.md`.

## Global Constraints

- **This is HITL.** It touches `~/.remem`, `~/Backups`, and the login Keychain. Nothing here runs unattended.
- **`~/.remem` is read-only for the whole plan.** No task may run `remem` or `recol` with `REMEM_DATA_DIR` unset or pointing at `~/.remem`. The single permitted access mode is reading files for `tar` and `shasum`.
- **Fixed paths**, used verbatim in every task so no shell state carries between them:
  - `SNAP` = `~/Backups/recol/2026-07-31`
  - `RESTORE` = `~/Backups/recol/2026-07-31/restore-test`
- **Every Bash invocation is a fresh shell.** Variables do not persist. Each task re-declares what it needs.
- **The snapshot passphrase is never written next to the archive.** It is read from Keychain service `recol-snapshot-key` into a `mktemp` file at the start of each task that needs it, and that file is deleted at the end of the same task.
- **`command remem`, never `remem`.** The `.zshrc` function injects `REMEM_CIPHER_KEY` and would mask the exact failure this plan exists to rule out.
- **macOS `xargs` has no `-a` flag.** File lists are piped through `tr '\n' '\0' | xargs -0`.
- **Order is load-bearing between Tasks 4 and 5.** Task 4 proves the restored tree is byte-identical to the baseline. Task 5 runs `status` against that tree, which mutates it. Running them out of order destroys the only proof the archive round-trips.
- **Snapshot size floor:** 157286400 bytes (150 MiB).
- **Expected inventory values**, from the plan's Context section: `Extract fail: 1`, `Replay todo: 1`, Memories 0, Observations 0, Sessions 0, Candidates 0, Graph queue 0, roughly 22,555 raw messages.

## File Structure

| Path | Created by | Responsibility |
|---|---|---|
| `docs/tasks/r0-11-inventory-and-snapshot.md` | Task 1 (modify) | The board's contract for this task; its acceptance criteria must match the spec |
| `project.md` | Tasks 1, 7 (modify) | Status board; R0-11 row and the Done table |
| `~/Backups/recol/2026-07-31/baseline.files` | Task 2 | Sorted list of files in `~/.remem`, relative to `~` |
| `~/Backups/recol/2026-07-31/baseline.sha256` | Task 2 | SHA-256 per file, in `shasum -c` format, relative paths |
| `~/Backups/recol/2026-07-31/baseline.stat` | Task 2 | Size, mtime, and mode per file; informational strictness |
| `~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg` | Task 3 | The artifact; AES-256 over an uncompressed tar |
| `~/Backups/recol/2026-07-31/snapshot.tar.sha256` | Task 3 | Checksum of the plaintext tar stream, captured in flight |
| `~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg.sha256` | Task 3 | Checksum of the ciphertext |
| `~/Backups/recol/2026-07-31/inventory.json` | Task 5 | Full `status --json`; not committed, carries project names |
| `~/Backups/recol/2026-07-31/doctor.json` | Task 5 | Full `doctor --json`; source of the applied schema version |
| `~/Backups/recol/2026-07-31/RESTORE.md` | Task 6 | How to restore, written for a reader who has no Keychain `remem-cipher-key` |
| `~/Backups/recol/2026-07-31/DO-NOT-DELETE.md` | Task 6 | The retention condition |
| `docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md` | Task 6 | Counts only, committed, every number carrying its JSON path |

---

### Task 1: Correct the task file and the board

The spec found three claims in `docs/tasks/r0-11-inventory-and-snapshot.md` that
do not survive contact with the code. That file is what the board points a future
reader at, so it must not keep stating criteria that cannot be met. This task
touches no machine state and can be reviewed on its own.

**Files:**
- Modify: `docs/tasks/r0-11-inventory-and-snapshot.md`
- Modify: `project.md:24-28` (the Next section) and `project.md:45` (the R0-11 row)

**Interfaces:**
- Consumes: nothing
- Produces: a task file whose acceptance criteria match
  `docs/specs/r0-11-inventory-and-snapshot/TECH.md`, so Tasks 2-7 can be checked
  against either document and get the same answer

- [ ] **Step 1: Read the current task file and the spec side by side**

```bash
cd /Users/mk/Code/recol--refactor-11
cat docs/tasks/r0-11-inventory-and-snapshot.md
cat docs/specs/r0-11-inventory-and-snapshot/PRODUCT.md
```

Expected: the task file's Context says `recol status`, its Scope says "Encrypted
archive of the whole `~/.remem` directory" with no mention of the cipher key, and
its acceptance criteria compare restored counts against the inventory.

- [ ] **Step 2: Replace the Context, Scope, and Acceptance criteria sections**

Replace everything from the `## Context` heading to the end of the file with:

```markdown
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
```

- [ ] **Step 3: Verify the file is internally consistent**

```bash
cd /Users/mk/Code/recol--refactor-11
rg -n "recol status|RECOL_DATA_DIR" docs/tasks/r0-11-inventory-and-snapshot.md
```

Expected: no output. Every command reference in this task file is `remem`, because
the rename has not happened yet.

- [ ] **Step 4: Point the board at the spec and the plan**

In `project.md`, replace the R0-11 row with:

```markdown
| [11 Inventory and snapshot](docs/tasks/r0-11-inventory-and-snapshot.md) | HITL | - | in progress |
```

and append to the `## Next` section, after the existing R0-11 paragraph:

```markdown
R0-11 has a spec at `docs/specs/r0-11-inventory-and-snapshot/` and an execution
plan at `docs/plan/20-rename-and-release/r0-11-execution-plan.md`. The spec
corrects three claims in the task file, the load-bearing one being that the
snapshot must carry its own SQLCipher key or R0-13 renders it unreadable.
```

- [ ] **Step 5: Commit**

```bash
cd /Users/mk/Code/recol--refactor-11
git add docs/tasks/r0-11-inventory-and-snapshot.md project.md
git commit -m "docs(tasks): correct R0-11 acceptance criteria against the code

The snapshot cannot restore without the Keychain key R0-13 deletes, and
reading the inventory from the live installation writes to it. Both
criteria are restated so the board matches docs/specs/."
```

---

### Task 2: Preconditions and cold checksum baseline

Nothing in this plan means anything without a baseline taken before the first
command runs. This task establishes it and confirms no process is writing to the
database, which is the one condition under which a cold `tar` would silently
capture a torn write.

**Files:**
- Create: `~/Backups/recol/2026-07-31/baseline.files`
- Create: `~/Backups/recol/2026-07-31/baseline.sha256`
- Create: `~/Backups/recol/2026-07-31/baseline.stat`

**Interfaces:**
- Consumes: nothing
- Produces: `baseline.sha256` in `shasum -c` format with paths relative to `~`,
  so the identical command verifies both `~/.remem` (run from `~`) and the
  restored tree (run from `$RESTORE`). Tasks 3, 4, and 7 all depend on that
  relative-path property.

- [ ] **Step 1: Confirm nothing is holding the database**

```bash
pgrep -fl 'remem|recol'
lsof ~/.remem/remem.db
```

Expected: both produce no output. Any match stops the task - shut the worker
down and start over. `pgrep` matching this plan's own shell is not a hit; look
for a `remem` or `recol` executable path.

- [ ] **Step 2: Confirm the cipher key is readable and the disk has room**

```bash
security find-generic-password -s remem-cipher-key -w | wc -c
df -g ~ | tail -1
```

Expected: the character count is greater than 1, and the available column is at
least 1. If the key read fails, stop: the archive would be built without the one
thing that makes it restorable.

- [ ] **Step 3: Create the snapshot directory**

```bash
mkdir -p ~/Backups/recol/2026-07-31
ls -ld ~/Backups/recol/2026-07-31
```

Expected: the directory exists.

- [ ] **Step 4: Take the baseline**

```bash
cd ~
find .remem -type f | sort > ~/Backups/recol/2026-07-31/baseline.files
tr '\n' '\0' < ~/Backups/recol/2026-07-31/baseline.files \
  | xargs -0 shasum -a 256 > ~/Backups/recol/2026-07-31/baseline.sha256
find .remem -type f -exec stat -f '%N %z %m %Lp' {} + | sort \
  > ~/Backups/recol/2026-07-31/baseline.stat
```

- [ ] **Step 5: Verify the baseline is well-formed and complete**

```bash
wc -l ~/Backups/recol/2026-07-31/baseline.sha256
cat ~/Backups/recol/2026-07-31/baseline.files
cd ~ && shasum -a 256 -c ~/Backups/recol/2026-07-31/baseline.sha256
```

Expected: 8 lines. The file list is `capture-spill.lock`, `config.toml`,
`config.toml.bak`, `remem.db`, `remem.log`, `remem.log.1`, `remem.log.lock`,
`worker.lock`, each prefixed `.remem/`. Every `shasum -c` line reports OK.

A different file count is not automatically a failure, but explain it before
continuing. A `.key` file appearing here would mean the environment changed since
the spec was written, and Task 3's key handling should be revisited.

- [ ] **Step 6: Record the result**

No commit - these artifacts live outside the repository. Report the file count,
the total byte size from `baseline.stat`, and the `shasum -c` result.

---

### Task 3: Build the encrypted archive and prove the source is unchanged

The archive is built by streaming, so no unencrypted 208 MB file ever lands on
disk. The passphrase reaches the Keychain before the archive is built, so a crash
mid-stream leaves a recoverable secret rather than an unopenable file.

**Files:**
- Create: `~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg`
- Create: `~/Backups/recol/2026-07-31/snapshot.tar.sha256`
- Create: `~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg.sha256`
- Create: Keychain generic password, service `recol-snapshot-key`, account `$USER`

**Interfaces:**
- Consumes: `baseline.sha256` and `baseline.files` from Task 2
- Produces: an archive whose members are `.remem/...` (paths relative to `~`)
  plus one top-level `remem-cipher-key.txt`. Task 4 relies on that exact layout:
  the key file is a sibling of `.remem/`, never inside it, so the archived
  directory stays byte-identical to the original.

**Steps 1 through 4 must run in one shell invocation.** `$PASS_FILE` and
`$KEY_DIR` are `mktemp` paths and do not survive a new shell. Concatenate the
four blocks into a single command, checking the expected output of each before
moving on. Step 5 is independent and may run separately.

- [ ] **Step 1: Mint the archive passphrase and store it in Keychain first**

```bash
PASS_FILE=$(mktemp); chmod 600 "$PASS_FILE"
openssl rand -base64 32 > "$PASS_FILE"
security add-generic-password -a "$USER" -s recol-snapshot-key \
  -w "$(cat "$PASS_FILE")" -U
security find-generic-password -s recol-snapshot-key -w | wc -c
```

Expected: the final count is 45 (44 base64 characters plus newline). If
`add-generic-password` fails, stop - do not build an archive whose passphrase
exists only in a temp file.

- [ ] **Step 2: Extract the SQLCipher key into a staging directory**

```bash
KEY_DIR=$(mktemp -d); chmod 700 "$KEY_DIR"
security find-generic-password -s remem-cipher-key -w > "$KEY_DIR/remem-cipher-key.txt"
chmod 600 "$KEY_DIR/remem-cipher-key.txt"
wc -c "$KEY_DIR/remem-cipher-key.txt"
```

Expected: a non-zero byte count. `load_cipher_key()` trims the value it reads, so
the trailing newline `security` emits is harmless.

- [ ] **Step 3: Build the archive**

Run this as a single block, in the same shell as Steps 1 and 2, because
`$PASS_FILE` and `$KEY_DIR` do not survive a new invocation:

```bash
tar -cf - -C ~ .remem -C "$KEY_DIR" remem-cipher-key.txt \
  | tee >(shasum -a 256 > ~/Backups/recol/2026-07-31/snapshot.tar.sha256) \
  | gpg --batch --yes --symmetric --cipher-algo AES256 \
        --passphrase-file "$PASS_FILE" \
        -o ~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg
print -r -- "pipe status: $pipestatus"
```

Expected: `pipe status: 0 0 0`. If `gpg` opens a pinentry prompt instead, cancel
it, delete the partial output, and re-run with `--pinentry-mode loopback` added.
Do not type the passphrase at a prompt; it would land in shell history.

- [ ] **Step 4: Checksum the ciphertext and clean up the passphrase file**

```bash
shasum -a 256 ~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg \
  > ~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg.sha256
rm -f "$PASS_FILE"
ls -l ~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg
```

Expected: size greater than 157286400 bytes. On the 2026-07-31 tree it should be
close to 208 MB, since the payload is high-entropy and uncompressed.

`$KEY_DIR` stays until Task 4 has confirmed the key file survived the round trip.

- [ ] **Step 5: Prove the archive step did not mutate the source**

```bash
cd ~
shasum -a 256 -c ~/Backups/recol/2026-07-31/baseline.sha256
find .remem -type f | sort | diff - ~/Backups/recol/2026-07-31/baseline.files
```

Expected: every line reports OK, and the `diff` produces no output.

A mismatch here means something wrote to `~/.remem` while `tar` was reading it.
Delete the archive, find the writer, and restart from Task 2. A snapshot taken
across a concurrent write is not worth keeping.

- [ ] **Step 6: Record the result**

Report the archive size, the ciphertext checksum, the plaintext tar checksum, and
the `shasum -c` outcome. No commit.

---

### Task 4: Restore the archive and prove byte equality

This is the acceptance criterion that matters. The task file phrases it as a
count comparison, which is circular once the inventory is read from the restored
copy. Byte equality is checked instead: it implies count equality, and the
reverse does not hold.

**Files:**
- Create: `~/Backups/recol/2026-07-31/restore-test/.remem/` (the restored tree)
- Create: `~/Backups/recol/2026-07-31/restore-test/remem-cipher-key.txt`

**Interfaces:**
- Consumes: `remem-snapshot.tar.gpg`, `baseline.sha256`, `baseline.files`, and
  Keychain service `recol-snapshot-key`
- Produces: a restored tree at `$RESTORE/.remem` that is byte-identical to
  `~/.remem`, and `$RESTORE/remem-cipher-key.txt`. Task 5 consumes both.

**Do not run any `remem` command in this task.** Task 5 does that, and it mutates
the restored tree. Every check below must complete first.

- [ ] **Step 1: Decrypt and extract**

```bash
PASS_FILE=$(mktemp); chmod 600 "$PASS_FILE"
security find-generic-password -s recol-snapshot-key -w > "$PASS_FILE"
mkdir -p ~/Backups/recol/2026-07-31/restore-test
gpg --batch --yes --decrypt --passphrase-file "$PASS_FILE" \
    ~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg \
  | tar -xf - -C ~/Backups/recol/2026-07-31/restore-test
print -r -- "pipe status: $pipestatus"
rm -f "$PASS_FILE"
```

Expected: `pipe status: 0 0`. `gpg` writes progress to stderr; that is not an
error.

- [ ] **Step 2: Confirm the archive layout**

```bash
find ~/Backups/recol/2026-07-31/restore-test -type f \
  | sed "s|$HOME/Backups/recol/2026-07-31/restore-test/||" | sort
```

Expected: `remem-cipher-key.txt` at the top level, plus the eight `.remem/`
entries from `baseline.files`. Nine paths total.

- [ ] **Step 3: Verify every restored file byte for byte**

```bash
cd ~/Backups/recol/2026-07-31/restore-test
shasum -a 256 -c ~/Backups/recol/2026-07-31/baseline.sha256
```

Expected: every line reports OK. This is the proof the whole task exists to
produce.

A "No such file or directory" here means the extraction root is wrong or the tar
was built without `-C ~`; both produce the same symptom.

- [ ] **Step 4: Verify nothing was added or dropped inside `.remem/`**

```bash
cd ~/Backups/recol/2026-07-31/restore-test
find .remem -type f | sort | diff - ~/Backups/recol/2026-07-31/baseline.files
```

Expected: no output.

- [ ] **Step 5: Confirm the key file is non-empty, then discard the staging copy**

```bash
wc -c ~/Backups/recol/2026-07-31/restore-test/remem-cipher-key.txt
```

Expected: the same byte count as Task 3 Step 2. The `$KEY_DIR` from Task 3 may
now be deleted; if that shell is gone, `mktemp` directories under
`/var/folders` are cleaned by the system.

- [ ] **Step 6: Record the result**

Report the number of files verified, the `shasum -c` outcome, and the `diff`
outcome. No commit.

---

### Task 5: Prove the restored copy opens without the Keychain

R1 runs after R0-13 has deleted `remem-cipher-key`. This task simulates that
world: no environment variable, no Keychain lookup, no `.zshrc` wrapper. If the
database opens anyway, the snapshot is genuinely self-sufficient.

**Files:**
- Create: `~/Backups/recol/2026-07-31/restore-test/.remem/.key`
- Create: `~/Backups/recol/2026-07-31/inventory.json`
- Create: `~/Backups/recol/2026-07-31/doctor.json`

**Interfaces:**
- Consumes: the verified restored tree from Task 4
- Produces: `inventory.json` conforming to `StatusReport`
  (`src/cli/actions/query/status/types.rs:6`) and `doctor.json` conforming to
  the doctor JSON shape with `.checks[]` carrying `name`, `status`, `detail`.
  Task 6 reads specific paths out of both.

- [ ] **Step 1: Place the key where `load_cipher_key()` looks for it**

```bash
cp ~/Backups/recol/2026-07-31/restore-test/remem-cipher-key.txt \
   ~/Backups/recol/2026-07-31/restore-test/.remem/.key
chmod 600 ~/Backups/recol/2026-07-31/restore-test/.remem/.key
ls -l ~/Backups/recol/2026-07-31/restore-test/.remem/.key
```

Expected: present, mode `-rw-------`.

This is the step that makes the restored tree diverge from the baseline. It is
correct and expected; Task 4's proof is already recorded.

- [ ] **Step 2: Open the database with both other key sources removed**

```bash
env -u REMEM_CIPHER_KEY \
    REMEM_DATA_DIR=$HOME/Backups/recol/2026-07-31/restore-test/.remem \
    command remem status --json > ~/Backups/recol/2026-07-31/inventory.json
echo "exit=$?"
```

Expected: `exit=0` and a JSON file of non-trivial size.

Failing with "refusing to open remem database without a SQLCipher key" means the
key did not survive the round trip, and the task has failed at its most important
claim. Do not work around it by exporting `REMEM_CIPHER_KEY`; that would produce
a green result for an archive R1 cannot open.

- [ ] **Step 3: Confirm it read the restored copy and not the original**

```bash
jq -r '.database.path' ~/Backups/recol/2026-07-31/inventory.json
```

Expected: a path under `~/Backups/recol/2026-07-31/restore-test/.remem`. Anything
under `~/.remem` invalidates both this task and Task 7, and means `REMEM_DATA_DIR`
did not take effect.

- [ ] **Step 4: Assert the irreplaceable row is present**

```bash
jq -e '.capture_pipeline.extract_failed == 1' ~/Backups/recol/2026-07-31/inventory.json
jq -e '.capture_pipeline.retryable_replay_ranges == 1' ~/Backups/recol/2026-07-31/inventory.json
```

Expected: both print `true` and exit 0. These are R1 step 2's replay target. If
either is 0, the snapshot does not contain what R1 needs.

- [ ] **Step 5: Capture the applied schema version**

```bash
env -u REMEM_CIPHER_KEY \
    REMEM_DATA_DIR=$HOME/Backups/recol/2026-07-31/restore-test/.remem \
    command remem doctor --json > ~/Backups/recol/2026-07-31/doctor.json
jq -r '.checks[] | select(.name | test("schema"; "i")) | "\(.name) [\(.status)] \(.detail)"' \
  ~/Backups/recol/2026-07-31/doctor.json
```

Expected: a line containing `migrations v<N>` and `sqlite user_version`. `doctor`
may exit non-zero if unrelated checks warn or fail; that does not block this task,
but note which checks failed.

`status --json` reports `.version` as the version the *binary* supports, not the
version the *database* is at. Both numbers go into the inventory.

- [ ] **Step 6: Record the result**

Report the `.database.path`, both assertions, and the schema check detail line.
No commit.

---

### Task 6: Record the inventory and write the restore runbook

R1 reads `RESTORE.md` months from now, in a world where `remem-cipher-key` no
longer exists and the binary is called `recol`. It has to be complete on its own.

**Files:**
- Create: `docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md`
- Create: `~/Backups/recol/2026-07-31/RESTORE.md`
- Create: `~/Backups/recol/2026-07-31/DO-NOT-DELETE.md`

**Interfaces:**
- Consumes: `inventory.json` and `doctor.json` from Task 5
- Produces: `INVENTORY.md`, which R0-12 compares its post-re-ingest counts
  against. R0-12's criterion is "greater than or equal to", because transcripts
  accumulate.

- [ ] **Step 1: Generate the inventory table**

```bash
jq -r '
  "| Field | Value | JSON path |",
  "|---|---|---|",
  "| Binary version and supported schema | \(.version) | `.version` |",
  "| Raw messages | \(.totals.raw_messages) | `.totals.raw_messages` |",
  "| Memories | \(.totals.memories) | `.totals.memories` |",
  "| Observations | \(.totals.observations) | `.totals.observations` |",
  "| Sessions | \(.totals.sessions) | `.totals.sessions` |",
  "| Pending candidates | \(.capture_pipeline.pending_candidates) | `.capture_pipeline.pending_candidates` |",
  "| Graph queue | \(.capture_pipeline.pending_graph_candidates) | `.capture_pipeline.pending_graph_candidates` |",
  "| Extract fail | \(.capture_pipeline.extract_failed) | `.capture_pipeline.extract_failed` |",
  "| Replay todo | \(.capture_pipeline.retryable_replay_ranges) | `.capture_pipeline.retryable_replay_ranges` |",
  "| Database size (bytes) | \(.database.size_bytes) | `.database.size_bytes` |"
' ~/Backups/recol/2026-07-31/inventory.json
```

Expected: eleven lines of markdown. Paste them verbatim into `INVENTORY.md` in
Step 2 - do not retype the numbers.

- [ ] **Step 2: Write `docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md`**

Use this structure, substituting the generated table and the schema detail line
from Task 5 Step 5:

```markdown
# R0-11 inventory - `~/.remem` as of 2026-07-31

Read from the restored snapshot, not from the live installation. `remem status`
runs migrations against a WAL store, so the original was never opened by the
binary. See `TECH.md` for why.

Source: `~/Backups/recol/2026-07-31/inventory.json`, produced by
`remem status --json` against the restored copy.

<generated table from Step 1>

## Schema

Applied migration version and SQLite `user_version`, from
`~/Backups/recol/2026-07-31/doctor.json`:

<schema check detail line from Task 5 Step 5>

## Snapshot

| | |
|---|---|
| Archive | `~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg` |
| Ciphertext SHA-256 | <from remem-snapshot.tar.gpg.sha256> |
| Plaintext tar SHA-256 | <from snapshot.tar.sha256> |
| Passphrase | Keychain service `recol-snapshot-key` |
| Restore instructions | `~/Backups/recol/2026-07-31/RESTORE.md` |

## What R0-12 compares against

`recol status` after re-ingest must report a raw message count **greater than or
equal to** the raw messages row above. Transcripts accumulate between the two
runs, so a larger number is expected and a smaller one is a failure.
```

Every angle-bracketed placeholder above is filled from a file produced by Tasks
3 and 5. None may remain in the committed file.

- [ ] **Step 3: Write `RESTORE.md` beside the archive**

```markdown
# Restoring the R0-11 snapshot

Taken 2026-07-31 from `~/.remem`, before the remem -> recol rename.

The archive contains the `~/.remem` directory verbatim plus a top-level
`remem-cipher-key.txt`. The key is a **sibling** of `.remem/`, not a member of
it, so the archived directory is byte-identical to the original.

The passphrase is in the login Keychain under service `recol-snapshot-key`.
That entry is deliberately separate from `remem-cipher-key`, which R0-13 deletes.

```bash
DEST=/tmp/remem-restore            # any empty directory
PASS_FILE=$(mktemp); chmod 600 "$PASS_FILE"
security find-generic-password -s recol-snapshot-key -w > "$PASS_FILE"

mkdir -p "$DEST"
gpg --batch --decrypt --passphrase-file "$PASS_FILE" \
    /Users/mk/Backups/recol/2026-07-31/remem-snapshot.tar.gpg \
  | tar -xf - -C "$DEST"
rm -f "$PASS_FILE"

cp "$DEST/remem-cipher-key.txt" "$DEST/.remem/.key"
chmod 600 "$DEST/.remem/.key"
```

The key must be copied into `.remem/.key` because `load_cipher_key()` reads
`REMEM_CIPHER_KEY` first, then `<data_dir>/.key`, and nothing else - the
binary will not find the key sitting beside the data directory.

Verify the restore against `baseline.sha256` before trusting it:

```bash
cd "$DEST" && shasum -a 256 -c /Users/mk/Backups/recol/2026-07-31/baseline.sha256
```

Run that **before** any `status` or `doctor` command. Those open the database
read-write and run migrations, after which the checksums no longer match.

Then point the binary at it. The variable name follows whatever the binary is
called at the time - `REMEM_DATA_DIR` before the rename, `RECOL_DATA_DIR` after:

```bash
env -u RECOL_CIPHER_KEY RECOL_DATA_DIR="$DEST/.remem" command recol status
```

Both `env -u RECOL_CIPHER_KEY` and `command` are required, not optional
hardening: the `.zshrc` `recol` function injects `RECOL_CIPHER_KEY` read from
Keychain `recol-cipher-key`, which belongs to the new installation, and
`load_cipher_key()` checks the environment variable before the `.key` file -
so without both, the wrapper hands the restored database the wrong key and
the failure looks like a corrupt archive rather than a wrong key source.

## What this snapshot is for

Extraction task id 1, from synthetic session `manual-eval-1785099656`. It shows
as `Extract fail: 1` and `Replay todo: 1`. R1 step 2 replays it to classify the
extraction failure as configuration or structural. There is no CLI export path
for a single extraction task, which is why the whole directory was archived.

## When done

Delete `$DEST`. It holds a plaintext `.key` beside a decryptable ~199 MB
database, and there is no reason to leave that lying around once the replay
is recorded.

```bash
rm -rf "$DEST"
```

This recursive delete may be refused by a local safety hook that flags it as
targeting a critical path. If that happens, stop and have a human run the
deletion or explicitly approve it. Do not work around the block by reaching
the same end state through a different command, such as `find -delete`.
```

- [ ] **Step 4: Write `DO-NOT-DELETE.md` beside the archive**

```markdown
# Do not delete

This snapshot outlives `~/.remem`. R0-13's acceptance criteria require it to
still be present and still restorable after the original directory and the
`remem-cipher-key` Keychain entry are gone.

Earliest safe deletion: after R1 step 2 has replayed extraction task 1 and its
result is recorded. Not a date - a condition.

Deleting Keychain service `recol-snapshot-key` destroys this archive as surely
as deleting the file.
```

- [ ] **Step 5: Verify no placeholder survived**

```bash
cd /Users/mk/Code/recol--refactor-11
rg -n '<[^>]+>|TBD|TODO' docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md
```

Expected: no output.

- [ ] **Step 6: Commit the inventory only**

```bash
cd /Users/mk/Code/recol--refactor-11
git add docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md
git commit -m "docs(specs): record the R0-11 inventory baseline

Counts read from the restored snapshot. R0-12 compares its post-re-ingest
raw message count against this, greater-than-or-equal."
```

`inventory.json` and `doctor.json` stay outside the repository: `.top_projects`
carries project names.

---

### Task 7: Final verification, cleanup, and board update

The restored copy holds a plaintext `.key` beside a decryptable 199 MB database.
It goes. The final sweep of `~/.remem` covers the whole plan, not just the
archive step, so it catches any command that touched the directory by accident.

**Files:**
- Delete: `~/Backups/recol/2026-07-31/restore-test/`
- Modify: `project.md` (R0-11 row and the Done table)

**Interfaces:**
- Consumes: `baseline.sha256`, `baseline.files`, `baseline.stat` from Task 2
- Produces: nothing downstream depends on. This is the closing gate.

- [ ] **Step 1: Final verification that `~/.remem` is untouched**

```bash
cd ~
shasum -a 256 -c ~/Backups/recol/2026-07-31/baseline.sha256
find .remem -type f | sort | diff - ~/Backups/recol/2026-07-31/baseline.files
```

Expected: every line reports OK, and the `diff` produces no output. This is the
task's last acceptance criterion.

- [ ] **Step 2: Check the stricter metadata comparison**

```bash
cd ~
find .remem -type f -exec stat -f '%N %z %m %Lp' {} + | sort \
  | diff - ~/Backups/recol/2026-07-31/baseline.stat
```

Expected: no output.

This one is informational. A difference here with identical checksums means
something opened a file without changing its contents - worth reporting, not a
failure.

- [ ] **Step 3: Remove the restored copy**

```bash
rm -rf ~/Backups/recol/2026-07-31/restore-test
ls ~/Backups/recol/2026-07-31
```

This recursive delete may be refused by a local safety hook that flags it as
targeting a critical path. If that happens, stop and report BLOCKED; have a
human run the deletion or explicitly approve a substitute command. Do not work
around the block by reaching the same end state through a different command
(for example `find -delete`) - the hook exists so an agent does not get to
rule the block a false positive and improvise past it on backup and key
material. This was observed on the 2026-07-31 run.

Expected: `RESTORE.md`, `DO-NOT-DELETE.md`, `baseline.files`, `baseline.sha256`,
`baseline.stat`, `doctor.json`, `inventory.json`, `remem-snapshot.tar.gpg`,
`remem-snapshot.tar.gpg.sha256`, `snapshot.tar.sha256`. No `restore-test`.

- [ ] **Step 4: Confirm the way back into the archive still exists**

```bash
security find-generic-password -s recol-snapshot-key -w > /dev/null; echo "exit=$?"
shasum -a 256 -c ~/Backups/recol/2026-07-31/remem-snapshot.tar.gpg.sha256
```

Expected: `exit=0`, and the checksum line reports OK. Run this last, so the task
does not end having discarded the only path into the archive.

- [ ] **Step 5: Update the board**

In `project.md`, set the R0-11 row status to `done`, and add a row to the `Done`
table:

```markdown
| R0-11 snapshot taken and proven restorable | `~/Backups/recol/2026-07-31/`, inventory at `docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md` |
```

Also update the `Last updated:` line at the top and revise the `## Next` section:
R0-11 is no longer the recommended starting point, so point at R0-01, R0-03, and
R0-08.

- [ ] **Step 6: Commit**

```bash
cd /Users/mk/Code/recol--refactor-11
git add project.md
git commit -m "docs: mark R0-11 done, snapshot proven restorable

Archive at ~/Backups/recol/2026-07-31/, passphrase in Keychain service
recol-snapshot-key. ~/.remem verified byte-identical against a baseline
taken before the task started."
```

- [ ] **Step 7: Report the closing state**

Report all five acceptance criteria from
`docs/specs/r0-11-inventory-and-snapshot/PRODUCT.md` with the command output that
satisfies each. A criterion without output backing it is not met.

---

## Rollback

Nothing in this plan modifies `~/.remem`, so there is nothing to roll back there;
if the final sweep fails, that is a bug in the plan, not a state to recover from.

To abandon the plan partway:

```bash
rm -rf ~/Backups/recol/2026-07-31
security delete-generic-password -s recol-snapshot-key
```

Do not run that once R0-13 has deleted `remem-cipher-key`. At that point the
archive is the only copy of the key, and the Keychain entry is the only way into
the archive.
