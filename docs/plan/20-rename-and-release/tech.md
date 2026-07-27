# R0 - Technical design

## Current code paths

The name is not one string. It is six layers, each resolved at a different
place, and each with a different blast radius.

**Build identity.** `Cargo.toml` declares `package.name = "remem-ai"`,
`lib.name = "remem"`, and a single `[[bin]]` named `remem` at `src/main.rs`.
`Cargo.lock` is keyed on `remem-ai`, and `check_plugin_version_sync.py` reads
that key by name, so the package rename changes what the checker looks for.

**Environment.** 138 distinct `REMEM_*` variables. Three carry live meaning:
`REMEM_CIPHER_KEY` in `load_cipher_key()` at `src/db/crypto.rs:36`,
`REMEM_DATA_DIR` in `data_dir()` at `src/db/core.rs:83`, and `REMEM_CONFIG` at
`src/runtime_config.rs:90`.

**On-disk state.** `data_dir()` returns `REMEM_DATA_DIR` if set, else
`~/.remem`. `db_path()` appends `remem.db`, `log_path()` at
`src/log/config.rs:36` appends `remem.log`, `src/runtime_config.rs:90` appends
`config.toml`, and `load_cipher_key()` appends `.key`.

**The Keychain service is not a code path.** `load_cipher_key()` checks the
environment variable and the `.key` file, and nothing else. `remem-cipher-key`
exists only in the user's `.zshrc` wrapper, which reads it and exports
`REMEM_CIPHER_KEY`. The binary has no business writing to a credential store it
does not read from; R6 adds first-class Keychain support.

**Distribution identity.** `Cargo.toml` for crates.io, `npm/remem/package.json`
as `@remem-ai/remem`, `server.json` as `io.github.majiayu000/remem`,
`plugins/remem/.codex-plugin/plugin.json`, and
`plugins/remem/runtimes/remem-releases.json`, read by
`plugins/remem/scripts/remem-runtime.js`.

**Governance.** `scripts/ci/` holds 5,745 lines of Python and `checks/` another
20 modules. Root-level `labels.yaml`, `states.yaml`, `workflow.yaml`, and
`skills-lock.json` configure SpecRail, and `.agents/skills/` carries
`remem-first-run-smoke` and `remem-plugin-version-sync`. `AGENTS.md:89`
mandates `check_pr_preflight.py` as the local preflight, so that script is
required by the agent router even though no workflow invokes it.

**CI.** `.github/workflows/ci.yml` is one 237-line `check` job on
`ubuntu-latest`. `cargo fmt` appears at line 188 and `cargo test` at line 237,
last. It triggers on `push: branches: [main]` and `pull_request`, so pushing a
feature branch exercises nothing; only a pull request does.

**Release.** `release.yml` runs five publish jobs behind a preflight requiring
three secrets, and packages the binary alone at line 84, with no `LICENSE`.
`auto-release.yml` fires on every green CI run on `main`, and carries the only
checks that tie a tag to a verified commit: exact-main-SHA verification and
immutable-tag handling.

**Repository protection does not exist.** `gh api` reports `rulesets: []`,
`branches/main/protection` 404 "Branch not protected", `environments: 0`, and
`actions/runners: total_count 0`.

## Design

### Phase ordering

Governance and protection come first because the later phases assume a
trustworthy gate and a protected tag, and neither exists today. CI rebuild
follows, because the rename needs a gate that actually reaches `cargo test`.
The rename follows that. The local cutover and the release come last, each
depending on a renamed, tested tree.

### Phase 0 - Governance trim and repository protection

Two coherent changes, not a pile of deletions.

Removed: `closure-audit.yml` and `sensitive-governance.yml`, both
`pull_request_target` with `issues: write`, which on a public repository is an
attack surface as well as dead process. From `scripts/ci/`:
`run_sensitive_implement_gate.py`, `check_pr_tier.py`, `check_spec_lifecycle.py`,
`closure_follow_up.py`, `extract_nonclosing_issue.py`, `specrail_sync_lock.py`,
and the six `test_*.py` files exercising them. Also `checks/`, `.specrail/`,
`scripts/sync-specrail-checks.sh`, root `labels.yaml`, `states.yaml`,
`workflow.yaml`, `skills-lock.json`, `npm/`, `server.json`, and the `epic`,
`spec`, and `implementation` issue templates.

Retained, because each still gates something real: `check_pr_preflight.py`
(mandated by `AGENTS.md`, and rewired to invoke only surviving checks),
`check_plugin_version_sync.py`, `check_public_surface.py`,
`check_public_claims.py`, `check_release_workflows.py`, `check_file_size.py`,
`check_version_bump.py`, `generate_plugin_release_manifest.py`, and
`smoke_native_web_api.sh`.

`AGENTS.md` and the pull request template are updated in the same commit to
describe exactly what survives. Leaving agent instructions pointing at deleted
executables is the failure mode this phase exists to avoid.

Protection is configured in this phase because Phase 1 onward describes work as
"merged behind green CI", which is currently unenforced:

- branch protection on `main` requiring the CI check and a linear history;
- a ruleset over `refs/tags/v*` restricting creation and blocking updates and
  deletes, so a published tag is immutable;
- a `release` environment with required reviewers, referenced by every
  publishing job.

### Phase 1 - CI rebuild

Three jobs, all on hosted runners.

`rust` on `ubuntu-latest`, in order: `cargo fmt --check`, `cargo clippy
--all-targets -- -D warnings`, `cargo test --locked`, then `check_file_size.py`,
`check_plugin_version_sync.py`, `check_public_surface.py`,
`check_public_claims.py`, `check_release_workflows.py`, the Node plugin tests,
the native web API smoke, an isolated first-run smoke, `eval-extraction --json
--check-baseline`, `eval-gates`, and the two constructed-regression proofs.

`macos-arm` on `macos-15` and `macos-intel` on `macos-15-intel`: `cargo build`
and `cargo test`. GitHub's hosted images cover both architectures;
`macos-latest`, `macos-14`, `macos-15`, and `macos-26` are ARM64, and the
`-intel` suffixed labels are x86_64. No self-hosted runner is registered.
Attaching a personal machine to a public repository would put the Keychain
holding the database key within reach of any pull request, and hosted ARM
removes the need entirely.

`--no-default-features` stays on `x86_64-apple-darwin` even on a native Intel
host. The ort constraint is on the target, not the builder: ONNX Runtime ships
no prebuilt binary for that target, so embedding falls back to the feature-hash
provider there and the degradation stays visible in `status` and `doctor`.

The Node plugin tests are retained deliberately. Deleting `npm/` removes the npm
wrapper test, not the plugin runtime, request-security, and app-server tests,
and this plan promises the plugin stays functional.

The isolated first-run smoke sets a temporary `HOME` and `RECOL_DATA_DIR`,
initializes, and confirms a clean start. Without it, nothing verifies that the
renamed data path works on a machine that has never had the old one.

Verification uses a pull request, not a branch push, because `push` triggers only
on `main`.

### Phase 2 - Rename

A scripted pass driven by an explicit manifest of paths and exceptions, not a
repository-wide substitution.

**Substitution order matters.** `remem-ai` is replaced before `remem`;
otherwise the sequential pass produces `recol-ai`. Case variants handled:
`remem-ai`, `remem`, `REMEM`, `Remem`.

**In scope**, beyond the obvious `src/`, `tests/`, `Cargo.toml`, `plugins/`,
`.github/`, `scripts/`, `install.sh`, `Dockerfile`, and the root markdown
files: `site/`, `eval/local/run_local_eval.py`, `eval/locomo/run_locomo.py`,
`CHANGELOG.md`, `.agents/skills/remem-first-run-smoke/` and
`remem-plugin-version-sync/`, `assets/`, `prompts/`, `schemas/`, the tracked
`.remem/` directory, and `docs/plan/`. Current architecture, plugin, and release
documents are updated; historical audits are not.

**Filenames are inventoried, not just contents.** `plugins/remem/` and its
`apps/remem/` and `skills/remem/` subtrees, the four `remem-*.js` runtime
scripts including `remem-runtime.test.js`, `runtimes/remem-releases.json`, the
two `.agents/skills/remem-*` directories, and the tracked `.remem/` directory.

**Frozen paths**: `src/migrations/`, `specs/`, `eval/`'s artifacts
(`golden.json`, the claims registry, locomo fixtures, `eval/public/reports/`),
and the audits and analyses under `docs/`.

**Preserved-literal allowlist.** These strings do not change anywhere, and the
rename audit asserts they are still present rather than absent:

| Literal | Frozen in | Also live in |
|---|---|---|
| `remem_static` | `v010_ai_usage_token_breakdown.sql:7` | `src/db/usage.rs:75`, `src/ai/pricing.rs:23`, `src/ai/tests.rs:128`, `src/db/query/stats/tests.rs` |
| `remem_static_backfill` | `v011_reprice_ai_usage_events.sql:88` | `src/migrate/tests.rs:367` |
| `remem_version` | `v063_procedure_exports.sql:14` | `src/memory/procedure/registry.rs:84,93`, `src/memory/procedure/export/render.rs:343` |
| `Copyright (c) 2026 majiayu000` | `LICENSE:3` | release archives |

`remem_version` is a live column, written by the procedure registry and emitted
as an export key. Renaming the SQL while the Rust holds, or the reverse, breaks
the procedure export silently.

**Version.** `Cargo.toml` moves to 0.7.0 and gains `publish = false`. The bump
is required by `check_version_bump.py`, whose `TRIGGER_PREFIXES` are `src/` and
`migrations/`, and 0.7.0 rather than a patch because renaming the binary, the
environment, and the data path without compatibility is breaking. `Cargo.lock`,
`plugin.json`, the release manifest, and `CHANGELOG.md` move with it, and
`check_plugin_version_sync.py` is updated in the same commit for the new lock
key and the removed npm and `server.json` sources.

**The rename audit** replaces the impossible assertion an earlier draft used.
It walks the in-scope manifest, ignores frozen paths, subtracts the
preserved-literal allowlist, and fails on any remaining occurrence. It also
asserts each allowlisted literal is still present, so a careless pass that
removed them fails too.

### Phase 3 - Recoverable local cutover

The database holds no curated state, but extraction task 1 is R1's replay target
and is not reproducible. The cutover is staged so every step is reversible until
the last.

1. Inventory: record table row counts from the old installation as a baseline.
2. Export the two artifacts that matter, extraction task 1 and `config.toml`, as
   named files, so R1 does not have to unpack 198 MB to find one row.
3. Snapshot: an encrypted archive of `~/.remem` to a rollback location.
4. Install the renamed build and, under a fresh `RECOL_DATA_DIR`, re-ingest and
   run representative searches, comparing against the inventory.
5. Only then move `~/.remem` aside and update the Keychain and the `.zshrc`
   wrapper. Delete the old directory and the old Keychain entry after the new
   installation has been verified, not before.

### Phase 4 - Release, staged then published

`release.yml` preflight requires `HOMEBREW_TAP_TOKEN` alone, and adds a check
proving the tag commit is the exact commit that passed CI on `main`, replacing
what `auto-release.yml` provided. Publishing jobs reference the `release`
environment, so a human approves.

The build matrix runs `aarch64-apple-darwin` on `macos-15`,
`x86_64-apple-darwin` on `macos-15-intel` with `--no-default-features`, and both
Linux targets on `ubuntu-latest`. Builds use `--locked`.

**Archives contain the binary and `LICENSE`.** The MIT notice must accompany
every copy, and the upstream copyright line is preserved.

**Staging never touches the production tap.** An earlier draft tagged a
throwaway prerelease, let it update `Formula/recol.rb`, then deleted the tag and
release, which would have left Homebrew pointing at deleted assets. Instead the
tap job runs in dry-run mode for prereleases, writing the formula to a staging
branch of the tap and not to `main`. Release-candidate assets are retained
immutably; nothing referenced by the production formula is ever deleted.

**The plugin manifest needs a post-release transition.** The checked-in
`recol-releases.json` is `state: "unreleased"`, and
`plugins/recol/scripts/recol-runtime.js:359` returns `null` for that state
before it ever consults a base URL, so uploading the manifest to the release
does not activate remote resolution. After the release publishes, a follow-up
commit updates the checked-in manifest with the published base URL and
checksums. This is verified by a smoke that runs with no repository binary and
nothing matching on `PATH`, and asserts the runtime downloads, verifies,
installs, and starts.

`brew audit --strict` and `brew test` run against the published formula, plus a
clean `brew install` on a machine without a prior installation.

`auto-release.yml` and `auto_release_check_tag_state.sh` are deleted, their
guarantees having moved into the tag ruleset and the release preflight.
`docs/release-lifecycle.md` is rewritten for two channels and tag-driven
releases.

## Tests

Phase 0 verifies by pull request: CI passes with the trimmed gate set, and `rg`
over `.github/`, `AGENTS.md`, and the PR template finds no reference to a
removed executable. Protection is verified by attempting a direct push to
`main` and a tag delete, both of which must be refused.

Phase 1 verifies on a pull request, since `push` triggers only on `main`. All
three jobs must run, and a deliberately broken test must fail the `rust` job in
minutes.

Phase 2 verifies with the full suite plus the rename audit described above.

Phase 3 verifies by comparing post-re-ingest row counts against the recorded
inventory and by running representative searches, before anything is deleted.

Phase 4 verifies against a release candidate that does not touch the production
tap, then the plugin download smoke, `brew audit`, `brew test`, and a clean
install, before the first production tag.

## Risks

**The `.zshrc` wrapper lives outside the repository.** It references both
`remem-cipher-key` and the `remem` command, and no repository change can update
it. Until it is edited, every invocation fails with a key error that reads like
something unrelated. Called out as an explicit manual step.

**Re-ingestion costs wall-clock time.** Roughly 1,900 files and 22,555 messages,
though no model calls, since `ingest-sessions` does not feed extraction. Re-ingest
before any phase that needs the corpus present.

**A blanket substitution would corrupt data semantics.** Running `sed` across the
tree would rewrite `remem_static` and `remem_version` and break the pricing
lookup and procedure export against values already stored. Mitigated by the
manifest, the allowlist, and the audit's presence assertions.

**The plugin resolver is the least-tested path.** It only matters after a real
release, which is precisely when it is hardest to fix. The no-binary download
smoke exists so the failure surfaces in CI rather than on a user's machine.

**Detachment closes the upstream pull request path.** R5 and R6's `upstream`
classification describes intent, not an available route.
