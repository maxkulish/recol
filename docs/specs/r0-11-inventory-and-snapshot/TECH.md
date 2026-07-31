# R0-11 - Inventory and snapshot the existing installation (technical)

Status: Current contract
Product: `PRODUCT.md`
Task: `docs/tasks/r0-11-inventory-and-snapshot.md`

## Verified code reality

Every claim below was read out of the tree at commit `f984e134`, and the live
installation was inspected on 2026-07-31.

**The cipher key has exactly two sources.** `load_cipher_key()` at
`src/db/crypto.rs:36` reads `REMEM_CIPHER_KEY` if non-empty, then
`<data_dir>/.key` if it exists, then gives up. `require_cipher_key_or_plaintext_override()`
refuses to open the database when both are absent unless
`REMEM_ALLOW_PLAINTEXT_DB=1`. There is no Keychain code path in the binary; the
`remem` shell function in `.zshrc` runs `security find-generic-password -s
remem-cipher-key -w` and exports the result.

**`~/.remem` holds no key file.** Its contents on 2026-07-31 were
`remem.db` (207,863,808 bytes), `remem.log` (3,589,514), `remem.log.1`
(5,735,113), `config.toml` (937), `config.toml.bak` (907), and three zero-byte
lock files: `capture-spill.lock`, `remem.log.lock`, `worker.lock`. Total 208 MB.
The database begins `42 89 98 00`, not `SQLite format 3`, confirming SQLCipher.

**`status` is a write.** `run_status()` at `src/cli/actions/query/status.rs:13`
calls `load_status_report()`, which calls `db::open_db()`. `open_db()` at
`src/db/core.rs:110` runs `migrate::run_migrations()` (line 127),
`ensure_vec_table()`, and `enforce_binary_policy_floor()`. The connection is
configured `PRAGMA journal_mode=WAL` (`src/db/core.rs:184`), so opening it
read-write creates and checkpoints WAL sidecars. Separately, any command that
logs appends to `<data_dir>/remem.log` via `src/log/write.rs`.

**Field paths in `status --json`.** The counts the acceptance criteria name are
not all where the task file implies. `StatusTotals`
(`src/cli/actions/query/status/types.rs:37`) carries `memories`,
`observations`, `sessions`, `raw_messages`. The failure counters print from
`capture_pipeline`, not `failure_lifecycle`: `extract_failed` at
`src/cli/actions/query/status.rs:447`, `retryable_replay_ranges` at 451, and
`pending_candidates` at 462.

**Schema version is not a `status` field.** `StatusReport.version` is
`build_info::version_label()`, formatted `"{package_version} (schema v{N})"`
where `N` is `migrate::latest_schema_version()` - the version the *binary*
supports, not the version the *database* is at. The applied migration version
and the SQLite `user_version` come from `remem doctor`, whose schema check
renders `migrations vN` and `sqlite user_version` (`src/doctor/schema.rs`).
Both are recorded.

**Nothing is holding the database.** `pgrep -fl 'remem|recol'` matched no
process and `lsof ~/.remem/remem.db` returned nothing on 2026-07-31, so a cold
archive cannot capture a torn write. This is re-checked at execution time
because it is a precondition, not a fact.

**Tooling.** `gpg` 2.x and `jq` are at `/opt/homebrew/bin`; `age` is not
installed. `shasum`, `tar`, and `security` are the system copies. The home
volume has 196 GB free against a peak requirement of roughly 620 MB.

macOS `xargs` is the BSD build and rejects `-a`, so the checksum sweep feeds the
file list through `tr` into `xargs -0`. The whole mechanism - two-`-C` tar,
`tee` into a process substitution, `gpg --batch --passphrase-file`, and
`shasum -c` against a relative-path baseline from a different extraction root -
was rehearsed on scratch data before this spec was written. `gpg` produced no
pinentry prompt.

## Design

### The ordering constraint

The task must prove `~/.remem` is untouched, and the only honest way to prove
that is to never let the binary open it. Every read that would mutate the
directory is moved onto the restored copy, which is disposable.

That inverts the naive order. The inventory is not the first step; it is the
last verification, produced from the restored tree. This costs nothing, because
the inventory's consumer is R0-12, which runs after all of Phase 2.

### Sequence

```
S0  preconditions              no process, key readable, disk headroom
S1  cold checksum baseline     the reference for S3, S4, and S7
S2  build the archive          tar --> gpg, source opened read-only
S3  verify source unchanged    snapshotting did not mutate ~/.remem
S4  restore and compare        the archive round-trips byte for byte
S5  open the restored copy     it decrypts with only the bundled .key
S6  record inventory           read from the restored copy
S7  verify source unchanged    nothing in the task touched the original
```

S3 and S7 run the same check for different reasons. S3 isolates the archive
step; S7 covers the whole task, including any accidental command.

### Key custody

The archive carries the Keychain value as a top-level file
`remem-cipher-key.txt`, a **sibling** of the archived `.remem/` directory rather
than a member of it. That placement is deliberate: it keeps the archived
`.remem/` byte-identical to the original, which is what makes the S4 comparison
a single `shasum -c` invocation against the S1 baseline.

Restore is then two steps: extract, then copy `remem-cipher-key.txt` to
`.remem/.key`. Because `load_cipher_key()` reads `<data_dir>/.key`, the restored
copy opens with no environment variable and no Keychain lookup. S5 proves this
by running with `REMEM_CIPHER_KEY` explicitly unset and by calling `command
remem` to bypass the `.zshrc` wrapper.

The archive's own passphrase goes to Keychain service `recol-snapshot-key`.
R0-13 deletes `remem-cipher-key` and creates `recol-cipher-key`; it does not
touch `recol-snapshot-key`. The snapshot therefore survives R0-13 intact, and
R0-13 needs no amendment.

### Archive format

`tar` without compression, piped through `gpg --symmetric --cipher-algo
AES256`. Compression is skipped because 199 MB of the 208 MB is high-entropy
SQLCipher output that will not compress; paying for it would slow the step for
no gain. gpg is chosen over `openssl enc` because it carries an integrity check,
and over an encrypted DMG because it is a stream and needs no mount.

The plaintext tar stream is checksummed in flight with `tee` into a process
substitution, so the archive's integrity can be verified end to end without ever
writing an unencrypted 208 MB file to disk.

### Baseline format

The baseline is produced from `~` with paths relative to it, so entries read
`.remem/remem.db`. The tar is created with `-C ~ .remem`, so extraction into any
root reproduces the same relative paths, and verification in both S3 and S4
reduces to `shasum -a 256 -c baseline.sha256` run from the appropriate
directory. Checksums alone do not detect *added* files, so each verification is
paired with a file-list diff.

## Procedure

Shell is zsh. `set -e` is not used, because several steps must report a failure
rather than abort the surrounding sequence; each step states its expected
outcome instead.

### S0 - Preconditions

```bash
SNAP=~/Backups/recol/2026-07-31
RESTORE=$(mktemp -d)/r0-11-restore

pgrep -fl 'remem|recol'                    # expect: no output
lsof ~/.remem/remem.db                     # expect: no output
security find-generic-password -s remem-cipher-key -w | wc -c   # expect: > 1
df -g ~ | tail -1                          # expect: >= 1 GB available
mkdir -p "$SNAP" "$RESTORE"
```

A matching `pgrep` or `lsof` line stops the task. Start the worker down, not the
archive up.

### S1 - Cold checksum baseline

```bash
cd ~
find .remem -type f | sort > "$SNAP/baseline.files"
tr '\n' '\0' < "$SNAP/baseline.files" | xargs -0 shasum -a 256 > "$SNAP/baseline.sha256"
find .remem -type f -exec stat -f '%N %z %m %Lp' {} + | sort > "$SNAP/baseline.stat"
wc -l "$SNAP/baseline.sha256"              # expect: 8
```

Eight files as of 2026-07-31. A different count is not a failure, but it must be
explained before continuing.

### S2 - Build the archive

```bash
PASS_FILE=$(mktemp); chmod 600 "$PASS_FILE"
KEY_DIR=$(mktemp -d); chmod 700 "$KEY_DIR"

openssl rand -base64 32 > "$PASS_FILE"
security add-generic-password -a "$USER" -s recol-snapshot-key \
  -w "$(cat "$PASS_FILE")" -U

security find-generic-password -s remem-cipher-key -w \
  > "$KEY_DIR/remem-cipher-key.txt"
chmod 600 "$KEY_DIR/remem-cipher-key.txt"

tar -cf - -C ~ .remem -C "$KEY_DIR" remem-cipher-key.txt \
  | tee >(shasum -a 256 > "$SNAP/snapshot.tar.sha256") \
  | gpg --batch --yes --symmetric --cipher-algo AES256 \
        --passphrase-file "$PASS_FILE" \
        -o "$SNAP/remem-snapshot.tar.gpg"
print -r -- "pipe status: $pipestatus"     # expect: 0 0 0

shasum -a 256 "$SNAP/remem-snapshot.tar.gpg" \
  > "$SNAP/remem-snapshot.tar.gpg.sha256"
ls -l "$SNAP/remem-snapshot.tar.gpg"       # expect: > 157286400 bytes
rm -f "$PASS_FILE"
```

The passphrase is written to Keychain before the archive is built, so a crash
mid-archive leaves a recoverable secret rather than an undecryptable file.

`$PASS_FILE` is removed at the end of S2. Because each step runs in its own
shell, S4 and any later step that needs the passphrase re-reads it from
Keychain `recol-snapshot-key` into a fresh temp file. `$KEY_DIR` is removed
only after S4 confirms the key file is inside the archive.

### S3 - Verify the source is unchanged

```bash
cd ~
shasum -a 256 -c "$SNAP/baseline.sha256"   # expect: every line OK
find .remem -type f | sort | diff - "$SNAP/baseline.files"   # expect: no output
```

### S4 - Restore and compare

```bash
PASS_FILE=$(mktemp); chmod 600 "$PASS_FILE"
security find-generic-password -s recol-snapshot-key -w > "$PASS_FILE"

gpg --batch --yes --decrypt --passphrase-file "$PASS_FILE" \
    "$SNAP/remem-snapshot.tar.gpg" \
  | tar -xf - -C "$RESTORE"
print -r -- "pipe status: $pipestatus"     # expect: 0 0
rm -f "$PASS_FILE"

cd "$RESTORE"
shasum -a 256 -c "$SNAP/baseline.sha256"   # expect: every line OK
find .remem -type f | sort | diff - "$SNAP/baseline.files"   # expect: no output
ls -l "$RESTORE/remem-cipher-key.txt"      # expect: present, non-empty
```

This is the acceptance criterion the task file states as a count comparison. Byte
equality is stronger and is what is checked.

### S5 - Prove the restored copy opens

```bash
cp "$RESTORE/remem-cipher-key.txt" "$RESTORE/.remem/.key"
chmod 600 "$RESTORE/.remem/.key"

env -u REMEM_CIPHER_KEY REMEM_DATA_DIR="$RESTORE/.remem" \
  command remem status --json > "$SNAP/inventory.json"
env -u REMEM_CIPHER_KEY REMEM_DATA_DIR="$RESTORE/.remem" \
  command remem doctor --json > "$SNAP/doctor.json"
```

`command remem` bypasses the `.zshrc` function, and `env -u REMEM_CIPHER_KEY`
removes the other key source. If either file is produced, the archive is
self-sufficient. If both commands fail with "refusing to open remem database
without a SQLCipher key", the key file did not survive the round trip and the
task has failed at its most important claim.

Assertions:

```bash
jq -e '.capture_pipeline.extract_failed == 1' "$SNAP/inventory.json"
jq -e '.capture_pipeline.retryable_replay_ranges == 1' "$SNAP/inventory.json"
jq -r '.database.path' "$SNAP/inventory.json"   # expect: under $RESTORE
```

The third assertion guards against the run having silently fallen back to
`~/.remem`, which would invalidate S7 as well as S5.

### S6 - Record the inventory

```bash
jq '{
  version: .version,
  raw_messages: .totals.raw_messages,
  memories: .totals.memories,
  observations: .totals.observations,
  sessions: .totals.sessions,
  pending_candidates: .capture_pipeline.pending_candidates,
  pending_graph_candidates: .capture_pipeline.pending_graph_candidates,
  extract_failed: .capture_pipeline.extract_failed,
  retryable_replay_ranges: .capture_pipeline.retryable_replay_ranges,
  database_size_bytes: .database.size_bytes
}' "$SNAP/inventory.json"

jq -r '.checks[] | select(.name | test("schema"; "i")) | .detail' "$SNAP/doctor.json"
```

Those values are transcribed into
`docs/specs/r0-11-inventory-and-snapshot/INVENTORY.md`, each with the JSON path
it came from. `inventory.json` and `doctor.json` stay under `$SNAP` and are not
committed: `.top_projects` carries project names.

`RESTORE.md` is written beside the archive, naming the Keychain service, the gpg
invocation, and the two-step key placement. R1 reads it months from now, after
`remem-cipher-key` no longer exists.

### S7 - Final verification of the source

```bash
cd ~
shasum -a 256 -c "$SNAP/baseline.sha256"   # expect: every line OK
find .remem -type f | sort | diff - "$SNAP/baseline.files"   # expect: no output
find .remem -type f -exec stat -f '%N %z %m %Lp' {} + | sort \
  | diff - "$SNAP/baseline.stat"           # expect: no output
```

The `stat` comparison is the strictest of the three and is informational: an
mtime change with identical content means something opened a file without
writing to it, which is worth knowing but does not fail the task.

### S8 - Clean up

```bash
rm -rf "$KEY_DIR" "$RESTORE"
security find-generic-password -s recol-snapshot-key -w > /dev/null   # expect: exit 0
```

These recursive deletes may be refused by a local safety hook that flags them
as targeting a critical path. If that happens, stop and report BLOCKED; have a
human run the deletion or explicitly approve a substitute command. Do not work
around the block by reaching the same end state through a different command
(for example `find -delete`) - the hook exists so an agent does not get to
rule the block a false positive and improvise past it on backup and key
material. This was observed on the 2026-07-31 run.

The restored copy is removed because it holds a plaintext `.key` beside a
decryptable database. The Keychain check is last so the task does not end having
discarded the only path back into the archive.

## Failure modes

**`gpg` prompts for a passphrase.** `--batch` plus `--passphrase-file` should
suppress pinentry. If a prompt appears, add `--pinentry-mode loopback`. Do not
work around it by typing the passphrase, which leaves it in shell history.

**A file changes between S1 and S3.** Something is running. Stop it, delete the
archive, and restart from S0. A snapshot taken across a concurrent write is not
worth keeping, and the checksum mismatch is the only signal that it happened.

**`shasum -c` reports a missing file in S4.** The extraction root is wrong, or
the tar was created without `-C ~`. Both produce the same symptom.

**The restored copy reports counts of zero.** The database opened but is empty,
which means a fresh store was created rather than the restored one being used.
Check `.database.path` in `inventory.json`.

**Disk fills mid-archive.** Peak usage is roughly 620 MB: 208 MB archive, 208 MB
restored copy, plus slack. 196 GB is available, so this should not occur; if it
does, the partial `.gpg` file is not recoverable and S2 restarts.

## Retention

The snapshot is kept until R1 step 2 has completed and its result recorded. R0-13
lists "the R0-11 snapshot is still present and still restorable" as an acceptance
criterion, so it must outlive the deletion of `~/.remem` by design. A
`DO-NOT-DELETE.md` note beside the archive records the earliest safe deletion
condition rather than a date.
