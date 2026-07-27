# R0-09 - Rename the build surfaces and bump to 0.7.0

Type: **AFK** | Blocked by: R0-07, R0-08 | Blocks: R0-10
Phase: 2 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 2)

## Goal

The project builds, tests, and reports itself as `recol` 0.7.0.

## Context

This task is inherently atomic. Changing `lib.name` breaks every consumer at
once, and `tests/search_latency_benchmark.rs` and
`tests/rule_enforcement_fixtures.rs` both `use remem::`, so `tests/` must move in
the same commit or the build fails.

**Substitution order matters.** Replace `remem-ai` **before** `remem`, then
`REMEM`, then `Remem`. Reversing the first two produces `recol-ai`.

**Version 0.7.0, not a patch.** `check_version_bump.py` has
`TRIGGER_PREFIXES = ("src/", "migrations/")`, so any `src/` change on a pull
request requires a bump. 0.7.0 rather than 0.6.28 because renaming the binary,
the environment variables, and the data path without a compatibility layer is a
breaking change on a pre-1.0 project.

**`Cargo.lock` is name-keyed.** `check_plugin_version_sync.py` reads the
`remem-ai` entry by name, so the checker must be updated in this same commit or
version sync fails immediately after the rename.

Add `publish = false` while here: crates.io publishing is abandoned, and the
flag makes accidental publication impossible rather than merely unlikely.

The rename audit will still fail after this task. That is expected - R0-10
covers the non-build surfaces.

## Scope

- [ ] `Cargo.toml`: `name = "recol"`, `lib.name = "recol"`, `[[bin]] name = "recol"`,
      `version = "0.7.0"`, `publish = false`, repository and homepage on
      `maxkulish/recol`
- [ ] `src/` excluding `src/migrations/`, and `tests/`
- [ ] `plugins/` including directory and filename moves: `plugins/remem/` with
      its `apps/remem/` and `skills/remem/` subtrees, the four `remem-*.js`
      scripts including `remem-runtime.test.js`, and
      `runtimes/remem-releases.json`
- [ ] `.github/`, `scripts/`, `install.sh`, `Dockerfile`
- [ ] `Cargo.lock`, `plugin.json`, release manifest, and `CHANGELOG.md` to 0.7.0
- [ ] `check_plugin_version_sync.py` updated for the new lock key

## Acceptance criteria

- [ ] `cargo fmt --check` exits 0
- [ ] `cargo clippy --all-targets -- -D warnings` exits 0
- [ ] `cargo test --locked --workspace` exits 0
- [ ] `cargo build --release` produces `target/release/recol`, and `target/release/recol --version` prints `recol 0.7.0`
- [ ] `grep -E '^(name|version|publish)' Cargo.toml` shows `recol`, `0.7.0`, `false`
- [ ] `python3 scripts/ci/check_plugin_version_sync.py` exits 0
- [ ] `rg -n "use remem::|remem::" tests/ src/` returns nothing
- [ ] `python3 scripts/ci/rename_audit.py` still reports all four allowlisted literals PRESENT
