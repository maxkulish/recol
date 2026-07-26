# R0 - Technical design

## Current code paths

The name is not one string. It is six layers, each resolved at a different
place, and each with a different blast radius.

**Build identity.** `Cargo.toml` declares `package.name = "remem-ai"`,
`lib.name = "remem"`, and a single `[[bin]]` named `remem` at `src/main.rs`.
The crate is published to crates.io as `remem-ai`; the fork will not publish
there, so the plain name `recol` is free for all three.

**Environment.** 138 distinct `REMEM_*` variables, read throughout `src/`.
Three carry live meaning today: `REMEM_CIPHER_KEY`, consumed by
`load_cipher_key()` at `src/db/crypto.rs:36`; `REMEM_DATA_DIR`, consumed by
`data_dir()` at `src/db/core.rs:83`; and `REMEM_CONFIG`, consumed at
`src/runtime_config.rs:90`.

**On-disk state.** `data_dir()` returns `REMEM_DATA_DIR` if set, else
`~/.remem`. Everything else derives from it: `db_path()` appends `remem.db`,
`log_path()` at `src/log/config.rs:36` appends `remem.log`,
`src/runtime_config.rs:90` appends `config.toml`, and `load_cipher_key()`
appends `.key`.

**The Keychain service is not a code path.** `load_cipher_key()` checks the
environment variable and the `.key` file, and nothing else. The service name
`remem-cipher-key` appears only in the user's `.zshrc` wrapper function, which
reads it and exports `REMEM_CIPHER_KEY` before invoking the binary. This is
worth stating precisely because it changes the migration design: the binary has
no business writing to the credential store it does not read from. R6 adds
first-class Keychain support; until then the service name is the user's
concern, not the program's.

**Distribution identity.** `Cargo.toml` for crates.io, `npm/remem/package.json`
as `@remem-ai/remem`, `server.json` as `io.github.majiayu000/remem`,
`plugins/remem/.codex-plugin/plugin.json`, and
`plugins/remem/runtimes/remem-releases.json`, which maps versions to release
assets and is read by `plugins/remem/scripts/remem-runtime.js`.

**CI.** `.github/workflows/ci.yml` is one 237-line `check` job on
`ubuntu-latest`. Its first fifteen steps are inherited governance; `cargo fmt`
appears at line 188 and `cargo test` at line 237, last. `release.yml` runs five
publish jobs behind a preflight requiring `CRATES_IO_TOKEN`,
`HOMEBREW_TAP_TOKEN`, and `NPM_TOKEN`. `auto-release.yml` fires on every
successful CI run on `main` and dispatches that release.

## Design

### Phase ordering

Deletion precedes renaming because roughly 6,000 lines slated for removal
contain the old name; renaming them first would be wasted work. CI rebuild
precedes the rename because the rename needs a gate that actually reaches
`cargo test`, which today's CI does not. The local reset follows the rename
because it installs the renamed build. Release comes last because it is the
only phase whose verification requires a tag.

### Phase 0 - Prune

Removed workflows: `closure-audit.yml` and `sensitive-governance.yml`, both
triggered by `pull_request_target` with `issues: write`. On a public repository
those are also an attack surface, so removing them is a security improvement
independent of the process argument.

Removed from `scripts/ci/`: `run_sensitive_implement_gate.py`,
`check_pr_tier.py`, `check_spec_lifecycle.py`, `closure_follow_up.py`,
`check_pr_preflight.py`, `extract_nonclosing_issue.py`, `specrail_sync_lock.py`,
`check_public_claims.py`, `check_public_surface.py`,
`check_release_workflows.py`, and the six `test_*.py` files that exercise them.
`check_pr_preflight.py` and `test_schema_contract.py` are already dead, wired
into no workflow.

Also removed: `checks/` (20 modules, the package those tests import from),
`.specrail/`, `scripts/sync-specrail-checks.sh`, `npm/`, `server.json`, and the
`epic`, `spec`, and `implementation` issue templates.

Retained: `check_file_size.py`, `check_version_bump.py`,
`generate_plugin_release_manifest.py`, `smoke_native_web_api.sh`, and
`check_plugin_version_sync.py` narrowed from four version sources to two,
`Cargo.toml` and the plugin runtime manifest, since npm and the MCP registry no
longer exist to synchronize against.

### Phase 1 - CI rebuild

Two jobs replace the single one.

`rust`, on `ubuntu-latest`: `cargo fmt --check`, `cargo clippy --all-targets --
-D warnings`, `cargo test`, then `check_file_size.py`, the native web API
smoke, `eval-extraction --json --check-baseline`, `eval-gates`, and the two
constructed-regression proofs that assert the gates actually block. The Rust
steps run first so a compile or test failure reports in minutes rather than
behind a governance queue.

`macos`, on `[self-hosted, macOS, ARM64]`: `cargo build` and `cargo test`
natively, guarded by

```yaml
if: >-
  github.event_name != 'pull_request' ||
  github.event.pull_request.head.repo.full_name == github.repository
```

so a pull request from an untrusted clone never executes on the runner's
machine. The repository setting *Actions -> Require approval for all outside
collaborators* backs this up; the guard is the control, the setting is the
backstop.

The eval gates are retained deliberately. `eval-extraction --check-baseline` is
the regression gate for exactly the extraction reliability R1 is about, and
losing it would make R1's quality changes unmeasurable.

### Phase 2 - Rename

A scripted pass over an explicit include-list of paths, not a repository-wide
substitution. Four case variants are handled: `remem`, `REMEM`, `Remem`, and
the compound `remem-ai`.

In scope: `src/` except `src/migrations/`, `tests/`, `Cargo.toml`,
`Cargo.lock`, `plugins/`, `.github/`, `scripts/`, `install.sh`, `Dockerfile`,
`README.md`, `README.zh-CN.md`, `AGENTS.md`, `CLAUDE.md`, `AGENT_USAGE.md`,
`CONTRIBUTING.md`, `SECURITY.md`, `.agents/`, `prompts/`, `schemas/`, and
`docs/plan/`.

Frozen: `src/migrations/`, `specs/`, `eval/`, `site/`, `CHANGELOG.md`, and the
audit and analysis documents under `docs/`.

The migration freeze is a correctness constraint, not a preference.
`v011_reprice_ai_usage_events.sql` sets `ai_usage_events.pricing_source` to the
literal `remem_static`, and matches on `remem_static` and
`remem_static_backfill`. `v063_procedure_exports.sql` declares a column
`remem_version`.

Deleting the current database does not relax this. Applied migrations are
immutable by construction, and every database they build, including one created
fresh after the rename, stores those same literals and that same column name.
Renaming them in the SQL while the Rust still matches on the old strings, or
the reverse, breaks the pricing lookup silently rather than loudly. Any Rust
code comparing against them keeps the literal; only new migrations use the new
name.

Directory moves: `plugins/remem/` to `plugins/recol/`, `plugins/remem/apps/remem/`
to `plugins/recol/apps/recol/`, `plugins/remem/skills/remem/` to
`plugins/recol/skills/recol/`, and the four `remem-*.js` runtime scripts to
`recol-*.js`. `runtimes/remem-releases.json` becomes `recol-releases.json`,
which `generate_plugin_release_manifest.py` and `release.yml` both reference.

Repository URLs move from `majiayu000/remem` to `maxkulish/recol`, and the
homepage from `majiayu000.github.io/remem` to the fork's own, or is dropped
where no replacement exists.

### Phase 3 - Local reset

No code. The database is a reproducible test corpus and the installed binary
came from crates.io, so both are deleted rather than migrated.

An earlier draft specified a `recol migrate` subcommand that would copy the
database, verify row counts, and re-key the Keychain. That design existed only
to protect state that turned out to be disposable. Building it would have added
a subcommand, its tests, and a `doctor` check, all to preserve something a
single `ingest-sessions` run regenerates.

What remains is a short sequence of manual commands: remove the crates.io
binary, remove `~/.remem`, generate a fresh cipher key into the Keychain under
`recol-cipher-key`, update the `.zshrc` wrapper to read it and export
`RECOL_CIPHER_KEY`, install the project build, and re-ingest.

Generating a new key rather than carrying the old one across is deliberate. The
old key exists to decrypt a database that is being deleted, so reusing it
inherits a secret for no reason.

### Phase 4 - Release and Homebrew

`release.yml` preflight requires only `HOMEBREW_TAP_TOKEN`.

The build matrix keeps four targets. `aarch64-apple-darwin` moves to the
self-hosted M1 runner and builds natively with default features.
`x86_64-apple-darwin` stays on `macos-latest` with `--no-default-features`,
since ONNX Runtime ships no prebuilt binary for Intel macOS and the build
cannot link it. The two Linux targets stay on `ubuntu-latest`, with the ARM64
cross-compilation toolchain as today.

The tap job checks out `maxkulish/homebrew-tap` and writes `Formula/recol.rb`
declaring `class Recol`, with the four platform URLs and checksums read from
the release's `SHA256SUMS`. `publish-crate`, `publish-npm`, and
`publish-mcp-registry` are deleted, as is `auto-release.yml` and its helper
`auto_release_check_tag_state.sh`. Releases are cut by pushing a `v*` tag or by
`workflow_dispatch` on a tag ref.

The formula's `caveats` block, which today instructs the user to run
`remem install --target claude`, is rewritten. That command wires SessionStart
injection and PostToolUse capture, which this project's design rejects; the
caveats should point at `recol doctor` instead.

## Tests

Phase 0 verifies by exclusion: `cargo test` exits 0 and no removed file is
referenced by a surviving workflow, checked with `rg` over `.github/`.

Phase 1 verifies on a branch push, which exercises the hosted job, and by
confirming the macOS job is skipped on a pull request from a clone and runs on
a push to `main`.

Phase 2 verifies with the existing suite plus two new assertions: `rg -i remem`
over the in-scope paths returns nothing, and `rg -n "remem_static|remem_version"`
over `src/` returns only the frozen migrations and the Rust literals that must
match them.

Phase 3 has no tests of its own. It is verified by outcome: `which remem`
returns nothing, `~/.remem` does not exist, and `recol status` opens a database
under `~/.recol` that a fresh `ingest-sessions` run has populated.

Phase 4 verifies against a prerelease tag on a throwaway version, confirming
four tarballs, a `SHA256SUMS` covering them, a formula commit in the tap, and
`brew install --build-from-source` succeeding, before the first real tag.

## Risks

**The `.zshrc` wrapper lives outside the repository.** It references both
`remem-cipher-key` and the `remem` command, and no repository change can update
it. If it is not edited, every post-rename invocation fails with "refusing to
open remem database without a SQLCipher key", which reads like an unrelated
error. The plan calls this out as an explicit manual step rather than assuming
it. This is the largest remaining risk, which is a measure of how much deleting
the database removed.

**Re-ingestion is not free.** Rebuilding the archive means reprocessing roughly
1,900 transcript files and 22,555 messages. It costs wall-clock time, though no
model calls, since `ingest-sessions` does not feed the extraction pipeline. If
a later phase needs the corpus present, re-ingest before that phase rather than
after.

**The self-hosted runner is attached to a public repository.** Untrusted pull
request code executing on that machine would have access to the Keychain
holding the database key. Mitigated by the trigger guard and the
outside-collaborator approval setting, both required before the runner is
registered.

**A blanket substitution would corrupt data semantics.** Running `sed` across
the tree would rewrite `remem_static` inside applied migrations and break the
match against values already stored. Mitigated by the explicit include-list and
by the post-rename assertion that the frozen literals survived.

**Detachment closes the upstream pull request path.** R5 and R6 are classified
`upstream`, and offering them now requires a fresh fork. This does not block any
work, but the roadmap's classification column should be read as aspiration
rather than a route that currently exists.
