# R0 - Tasks

Five phases, each its own branch off `main`, each merged behind green CI before
the next begins. The order is a dependency order; see `tech.md` for why.

Baseline to re-establish before starting: `cargo test --workspace` exits 0.
Verified green on 2026-07-26 at `f291d119`.

---

## Phase 0 - Prune

Branch: `chore/r0-prune-inherited-ci`

Deletion only. Nothing is renamed and no Rust source is touched, so a green
suite after this phase proves the removals were inert.

1. Delete `.github/workflows/closure-audit.yml` and
   `.github/workflows/sensitive-governance.yml`.
2. Delete from `scripts/ci/`: `run_sensitive_implement_gate.py`,
   `check_pr_tier.py`, `check_spec_lifecycle.py`, `closure_follow_up.py`,
   `check_pr_preflight.py`, `extract_nonclosing_issue.py`,
   `specrail_sync_lock.py`, `check_public_claims.py`,
   `check_public_surface.py`, `check_release_workflows.py`,
   `test_specrail_gate_wiring.py`, `test_closure_follow_up.py`,
   `test_sensitive_governance_workflow.py`,
   `test_run_sensitive_implement_gate.py`,
   `test_extract_nonclosing_issue.py`, and `test_schema_contract.py`.
3. Delete `checks/`, `.specrail/`, and `scripts/sync-specrail-checks.sh`.
4. Delete `npm/` and `server.json`.
5. Delete `.github/ISSUE_TEMPLATE/epic.yml`, `spec.yml`, and
   `implementation.yml`. Keep `bug_report.md`, `feature_request.md`,
   `memory_capture_bug.yml`, and `config.yml`.
6. Narrow `check_plugin_version_sync.py` to two version sources, `Cargo.toml`
   and the plugin runtime manifest, removing the npm and MCP-registry
   assertions.
7. Strip every step from `ci.yml` that invokes a file deleted above. Leave the
   remaining order untouched; Phase 1 restructures it.

Verify:

```bash
cargo test --workspace
rg -n "specrail|check_pr_tier|closure_follow_up|check_public_surface|server\.json|npm/" .github/ scripts/
```

The second command must return nothing. Done when both pass and the diff
contains no file outside the list above.

---

## Phase 1 - CI rebuild

Branch: `ci/r0-rust-first-and-macos`

Depends on Phase 0. Still named `remem` throughout; this phase only changes
what runs and where.

1. Rewrite `ci.yml` as two jobs. `rust` on `ubuntu-latest` runs, in order:
   `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
   `cargo test`, `check_file_size.py`, `scripts/smoke_native_web_api.sh`,
   `eval-extraction --json --check-baseline`, `eval-gates`, and the two
   constructed-regression proofs.
2. Add job `macos` on `[self-hosted, macOS, ARM64]` running `cargo build` and
   `cargo test`, guarded by
   `github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository`.
3. Keep `check_version_bump.py` on pull requests only.
4. Register the M1 runner with labels `self-hosted`, `macOS`, `ARM64`.
5. Enable *Settings -> Actions -> Require approval for all outside
   collaborators* before the runner comes online. This is a prerequisite, not a
   follow-up.

Verify: push the branch and confirm the `rust` job passes and reports a Rust
failure within minutes rather than behind a governance queue. Open a pull
request from a clone and confirm `macos` is skipped. Push to `main` after merge
and confirm `macos` runs.

---

## Phase 2 - Rename

Branch: `refactor/r0-rename-to-recol`

Depends on Phase 1, which supplies the gate this phase is verified by. The
single largest diff; do it in one pass so the tree is never half-renamed.

1. Write the include-list script. It substitutes `remem` to `recol`, `REMEM` to
   `RECOL`, `Remem` to `Recol`, and `remem-ai` to `recol`, across `src/`
   excluding `src/migrations/`, plus `tests/`, `Cargo.toml`, `plugins/`,
   `.github/`, `scripts/`, `install.sh`, `Dockerfile`, `README.md`,
   `README.zh-CN.md`, `AGENTS.md`, `CLAUDE.md`, `AGENT_USAGE.md`,
   `CONTRIBUTING.md`, `SECURITY.md`, `.agents/`, `prompts/`, `schemas/`, and
   `docs/plan/`.
2. Set `package.name`, `lib.name`, and the `[[bin]]` name to `recol`. Update
   `repository` and `homepage` to `maxkulish/recol`.
3. Move directories: `plugins/remem/` to `plugins/recol/`,
   `plugins/recol/apps/remem/` to `apps/recol/`,
   `plugins/recol/skills/remem/` to `skills/recol/`, the four `remem-*.js`
   runtime scripts to `recol-*.js`, and `runtimes/remem-releases.json` to
   `recol-releases.json`.
4. Update `generate_plugin_release_manifest.py` and `release.yml` to the new
   manifest filename.
5. Run `cargo fmt` and fix whatever the substitution broke, most likely
   `Cargo.lock` and any string assertion in tests that hardcoded the old name.
6. Regenerate `Cargo.lock` with `cargo check`.

Verify:

```bash
cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test --workspace
rg -i remem src/ tests/ plugins/ .github/ scripts/ Cargo.toml --glob '!src/migrations/**'
rg -n "remem_static|remem_version" src/
```

The second command must return nothing. The third must return only
`src/migrations/v011_reprice_ai_usage_events.sql`,
`src/migrations/v063_procedure_exports.sql`, and the Rust literals that match
them, which must not have changed.

---

## Phase 3 - Local reset

No branch, no code. Manual commands on the workstation, run once after Phase 2
merges.

The database is a reproducible test corpus and the installed binary came from
crates.io, so nothing here is migrated. Run these in order:

1. Remove the crates.io binary: `cargo uninstall remem-ai`, then confirm
   `which remem` returns nothing. Note the shell function shadows the binary,
   so remove it from `.zshrc` first or the check misreports.
2. Remove the old state: `rm -rf ~/.remem`.
3. Generate a fresh cipher key and store it:
   `security add-generic-password -s recol-cipher-key -a "$USER" -w "$(openssl rand -hex 32)"`.
   A new key rather than the old one, since the old key decrypts a database
   that no longer exists.
4. Replace the `.zshrc` wrapper function so it reads `recol-cipher-key`,
   exports `RECOL_CIPHER_KEY`, and invokes `recol`.
5. Install this project's build: `cargo install --path .`.
6. Re-ingest: `recol ingest-sessions`, then confirm `recol status` reports a
   populated archive under `~/.recol`.

Verify: `which recol` resolves to the cargo bin path, `recol --version` reports
the project's version rather than 0.6.27, and `~/.remem` does not exist.

Until step 4 is done, every invocation fails with "refusing to open recol
database without a SQLCipher key", which reads like an unrelated error. Nothing
in the repository can perform that step.

---

## Phase 4 - Release and Homebrew

Branch: `build/r0-release-github-and-tap`

Depends on Phase 2 for names and Phase 1 for the runner. Independent of Phase 3.

1. Narrow the `release.yml` preflight to `HOMEBREW_TAP_TOKEN` alone.
2. Move `aarch64-apple-darwin` to the self-hosted M1 runner with default
   features. Leave `x86_64-apple-darwin` on `macos-latest` with
   `--no-default-features`, and both Linux targets on `ubuntu-latest`.
3. Rename the artifacts to `recol-darwin-arm64`, `recol-darwin-x64`,
   `recol-linux-arm64`, `recol-linux-x64`, and the packaged binary to `recol`.
4. Retarget the tap job to `maxkulish/homebrew-tap`, writing `Formula/recol.rb`
   with `class Recol`.
5. Rewrite the formula `caveats`. The inherited text instructs the user to run
   `remem install --target claude`, which wires SessionStart injection and
   PostToolUse capture that this project's design rejects. Point at
   `recol doctor` instead.
6. Delete the `publish-crate`, `publish-npm`, and `publish-mcp-registry` jobs.
7. Delete `.github/workflows/auto-release.yml` and
   `scripts/ci/auto_release_check_tag_state.sh`.
8. Add `HOMEBREW_TAP_TOKEN` to the repository secrets, scoped to the tap
   repository only.
9. Update `docs/release-lifecycle.md` to describe tag-driven releases across two
   channels rather than auto-tagging across five.

Verify: tag a throwaway prerelease and confirm four tarballs, a `SHA256SUMS`
covering all four, a formula commit in the tap, and
`brew install maxkulish/tap/recol` producing a binary that reports
`recol <version>`. Delete the prerelease and its tag before the first real
release.

---

## Parallel splits

Phases 0 through 2 are strictly sequential. After Phase 2 merges, Phase 3 and
Phase 4 are independent and can proceed in either order or together. Phase 3
touches only the workstation and Phase 4 only the repository, so neither can
block the other.

R1 should not start until Phase 2 merges. It edits `src/observation_extract/`,
which the rename pass rewrites, and landing it first buys a merge conflict for
no benefit.
