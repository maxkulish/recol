# R0 - Tasks

Five phases, each its own branch, each merged through a pull request. Pull
requests, not branch pushes: `ci.yml` triggers on `push: branches: [main]` and
`pull_request`, so a feature-branch push exercises nothing.

Baseline: `cargo test --workspace` exits 0. Verified 2026-07-26 at `f291d119`.

---

## Phase 0 - Governance trim and repository protection

Branch: `chore/r0-governance-trim`

Two coherent changes: decide what governance survives, and give the repository
the protection the later phases assume. Not "deletion only"; this phase edits
`ci.yml`, `AGENTS.md`, and the preflight.

1. Delete `.github/workflows/closure-audit.yml` and
   `.github/workflows/sensitive-governance.yml`.
2. Delete from `scripts/ci/`: `run_sensitive_implement_gate.py`,
   `check_pr_tier.py`, `check_spec_lifecycle.py`, `closure_follow_up.py`,
   `extract_nonclosing_issue.py`, `specrail_sync_lock.py`,
   `test_specrail_gate_wiring.py`, `test_closure_follow_up.py`,
   `test_sensitive_governance_workflow.py`,
   `test_run_sensitive_implement_gate.py`,
   `test_extract_nonclosing_issue.py`, and `test_schema_contract.py`.
3. Delete `checks/`, `.specrail/`, `scripts/sync-specrail-checks.sh`, and the
   root SpecRail configuration: `labels.yaml`, `states.yaml`, `workflow.yaml`,
   `skills-lock.json`.
4. Delete `npm/`, `server.json`, and the `epic`, `spec`, and `implementation`
   issue templates.
5. Rewire `check_pr_preflight.py` to invoke only surviving checks. Do not delete
   it: `AGENTS.md:89` mandates it as the local preflight.
6. Update `AGENTS.md` and `.github/pull_request_template.md` in this same commit
   so no agent instruction points at a removed executable.
7. Strip every `ci.yml` step invoking a deleted file. Leave the remaining order
   alone; Phase 1 restructures it.
8. Configure protection:
   - branch protection on `main` requiring the CI check and linear history;
   - a ruleset over `refs/tags/v*` restricting creation, blocking update and
     delete, so published tags are immutable;
   - a `release` environment with required reviewers.

Verify: open a pull request and confirm CI passes with the trimmed gate set.
Then

```bash
rg -n "specrail|check_pr_tier|closure_follow_up|sensitive_implement|server\.json|npm/" .github/ scripts/ AGENTS.md
```

must return nothing. Confirm a direct push to `main` is refused and a `v*` tag
delete is refused.

---

## Phase 1 - CI rebuild

Branch: `ci/r0-rust-first-and-hosted-macos`

Depends on Phase 0. Still named `remem`; this phase changes only what runs and
where.

1. Rewrite `ci.yml` as three jobs. `rust` on `ubuntu-latest`, in order:
   `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
   `cargo test --locked`, `check_file_size.py`,
   `check_plugin_version_sync.py`, `check_public_surface.py`,
   `check_public_claims.py`, `check_release_workflows.py`, the Node plugin
   tests, `smoke_native_web_api.sh`, the isolated first-run smoke,
   `eval-extraction --json --check-baseline`, `eval-gates`, and the two
   constructed-regression proofs.
2. Add `macos-arm` on `macos-15` and `macos-intel` on `macos-15-intel`, each
   running `cargo build` and `cargo test`. Register no self-hosted runner.
3. Keep the Node plugin tests minus the deleted npm wrapper test: retain
   `plugins/remem/scripts/remem-runtime.test.js`,
   `apps/remem/request-security.test.js`, and `apps/remem/server.test.js`.
4. Add the isolated first-run smoke: temporary `HOME` and `REMEM_DATA_DIR`,
   initialize, assert a clean start with no pre-existing installation.
5. Keep `check_version_bump.py` on pull requests only.

Verify: open a pull request. All three jobs must run. Push a deliberately
broken test and confirm the `rust` job fails within minutes rather than behind a
governance queue, then revert it.

---

## Phase 2 - Rename

Branch: `refactor/r0-rename-to-recol`

Depends on Phase 1, which supplies the gate this phase is verified by. One pass,
so the tree is never half-renamed.

1. Write the manifest: in-scope paths, frozen paths, and the preserved-literal
   allowlist, as data the rename script and the audit both read.
2. Write the rename audit before the rename. It walks in-scope paths, skips
   frozen paths, subtracts allowlisted literals, fails on any remaining
   occurrence, and additionally asserts each allowlisted literal is still
   present. Confirm it fails against the current tree for the right reason.
3. Run the substitution, replacing `remem-ai` **before** `remem`, then `REMEM`,
   then `Remem`. Reversing the first two produces `recol-ai`.
4. In scope beyond the obvious: `site/`, `eval/local/run_local_eval.py`,
   `eval/locomo/run_locomo.py`, `CHANGELOG.md`, `.agents/skills/remem-first-run-smoke/`,
   `.agents/skills/remem-plugin-version-sync/`, `assets/`, `prompts/`,
   `schemas/`, the tracked `.remem/` directory, and the current architecture,
   plugin, and release documents under `docs/`.
5. Frozen: `src/migrations/`, `specs/`, `eval/golden.json`, the claims
   registry, the locomo fixtures, `eval/public/reports/`, and the audits and
   analyses under `docs/`.
6. Rename filenames, not only contents: `plugins/remem/` with its `apps/remem/`
   and `skills/remem/` subtrees, the four `remem-*.js` runtime scripts
   including `remem-runtime.test.js`, `runtimes/remem-releases.json`, both
   `.agents/skills/remem-*` directories, and `.remem/`.
7. Set `Cargo.toml` to version `0.7.0`, `package.name = "recol"`,
   `lib.name = "recol"`, the `[[bin]]` name to `recol`, `publish = false`, and
   the repository and homepage URLs to `maxkulish/recol`.
8. Move `Cargo.lock`, `plugin.json`, the release manifest, and `CHANGELOG.md` to
   0.7.0, and update `check_plugin_version_sync.py` for the new lock key and the
   removed npm and `server.json` sources, in this same commit.
9. Retarget `check_public_surface.py` and `check_public_claims.py` to the new
   identity and the two surviving channels.
10. Run `cargo fmt`, then `cargo check` to regenerate `Cargo.lock`.

Verify:

```bash
cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test --locked
python3 scripts/ci/rename_audit.py
python3 scripts/ci/check_plugin_version_sync.py
```

The audit must report zero unexpected occurrences **and** confirm all four
allowlisted literals survive: `remem_static`, `remem_static_backfill`,
`remem_version`, and the LICENSE copyright line.

---

## Phase 3 - Recoverable local cutover

No branch. Workstation commands, run once after Phase 2 merges. Every step is
reversible until the last.

1. Inventory the old installation: record table row counts as a baseline.
2. Export the two artifacts that are not reproducible: extraction task id 1 and
   `config.toml`. Save them as named files, so R1 step 2 does not have to unpack
   a 198 MB archive to find one row.
3. Snapshot: encrypted archive of `~/.remem` to a rollback location.
4. Install the renamed build with `cargo install --path .`.
5. Under a fresh `RECOL_DATA_DIR`, generate a key, re-ingest, and run
   representative searches. Compare row counts against step 1.
6. Only once step 5 passes: move `~/.remem` aside, add the
   `recol-cipher-key` Keychain entry, update the `.zshrc` wrapper to export
   `RECOL_CIPHER_KEY` and invoke `recol`, and remove the crates.io binary with
   `cargo uninstall remem-ai`.
7. Delete the old directory and the old Keychain entry only after the new
   installation has answered searches correctly.

Verify: `which recol` resolves to the cargo bin path, `recol --version` reports
0.7.0, and searches return results matching the pre-cutover inventory.

Until step 6's wrapper edit, every invocation fails with "refusing to open recol
database without a SQLCipher key", which reads like an unrelated error. Nothing
in the repository can perform that step.

---

## Phase 4 - Release, staged then published

Branch: `build/r0-release-github-and-tap`

Depends on Phase 2 for names and Phase 0 for the tag ruleset and release
environment. Independent of Phase 3.

1. Narrow the preflight to `HOMEBREW_TAP_TOKEN`, and add a check proving the tag
   commit is the exact commit that passed CI on `main`. This replaces what
   `auto-release.yml` provided.
2. Reference the `release` environment from every publishing job, so a human
   approves.
3. Set the matrix: `aarch64-apple-darwin` on `macos-15`, `x86_64-apple-darwin`
   on `macos-15-intel` with `--no-default-features`, both Linux targets on
   `ubuntu-latest`. Build with `--locked`.
4. Package the binary **and `LICENSE`** into every archive, preserving the
   upstream copyright line. Rename artifacts to `recol-darwin-arm64`,
   `recol-darwin-x64`, `recol-linux-arm64`, `recol-linux-x64`.
5. Add a dry-run mode to the tap job: for prereleases, render the formula and
   write it to a staging branch of `maxkulish/homebrew-tap`, never to its
   default branch. Production tags write `Formula/recol.rb` with `class Recol`.
6. Rename the formula `caveats` to `recol install --target codex|claude|all`.
   Nothing else about them changes. Removing hooks is R7's decision, not this
   phase's side effect.
7. Delete the `publish-crate`, `publish-npm`, and `publish-mcp-registry` jobs,
   `.github/workflows/auto-release.yml`, and
   `scripts/ci/auto_release_check_tag_state.sh`.
8. Add `HOMEBREW_TAP_TOKEN` to repository secrets, scoped to the tap only.
9. Add the plugin download smoke: no repository binary, nothing matching on
   `PATH`, asserting the runtime downloads, verifies, installs, and starts.
10. Rewrite `docs/release-lifecycle.md` for two channels and tag-driven
    releases.

Verify, in order:

- Cut a release candidate. Confirm four archives each containing the binary and
  `LICENSE`, a `SHA256SUMS` covering all four, and a formula written to the tap's
  **staging** branch only. Retain the RC; delete nothing.
- Run the plugin download smoke against the RC.
- Publish the production tag. Then commit the post-release manifest transition:
  update the checked-in `recol-releases.json` with the published base URL and
  checksums, because `recol-runtime.js:359` returns `null` while the state is
  `unreleased` and never consults a remote manifest.
- Run `brew audit --strict`, `brew test`, and a clean
  `brew install maxkulish/tap/recol` on a machine with no prior installation.

Never delete an asset the production formula references.

---

## Parallel splits

Phases 0 through 2 are strictly sequential. After Phase 2 merges, Phase 3 and
Phase 4 are independent: Phase 3 touches only the workstation, Phase 4 only the
repository.

R1 does not start until Phase 2 merges. It edits `src/observation_extract/`,
which the rename rewrites. R1 step 2 additionally depends on extraction task
id 1, which survives only inside R0-11's encrypted snapshot - there is no export
subcommand, so R1 step 2 restores the snapshot into a scratch data directory and
replays there. Do not run Phase 3's deletion step until that snapshot is proven
restorable.
