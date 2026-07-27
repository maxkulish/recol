# R0-05 - Rebuild ci.yml with the Rust gates first

Type: **AFK** | Blocked by: R0-02, R0-03 | Blocks: R0-04, R0-06, R0-07
Phase: 1 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 1)

## Goal

A compile or test failure reports in minutes instead of behind a queue of
gates, and the checks that still matter all run.

## Context

Today `ci.yml` is one 237-line `check` job. `cargo fmt` appears at line 188 and
`cargo test` at line 237, **last**. Everything before them is inherited
governance, so a governance failure means the Rust code is never compiled.

Retain and keep passing: `check_file_size.py`, `check_plugin_version_sync.py`,
`check_public_surface.py`, `check_public_claims.py`,
`check_release_workflows.py`, `smoke_native_web_api.sh`, the eval gates
(`eval-extraction --check-baseline`, `eval-gates`) and the two
constructed-regression proofs that assert those gates actually block, and
`check_version_bump.py` on pull requests only.

**Keep the Node plugin tests.** R0-03 deletes the npm wrapper test only. The
plugin runtime, request-security, and app-server tests stay, because this plan
promises the plugin remains functional:
`plugins/remem/scripts/remem-runtime.test.js`,
`plugins/remem/apps/remem/request-security.test.js`,
`plugins/remem/apps/remem/server.test.js`.

Name the job `rust`; R0-04 pins that name as a required status check.

Verification uses a **pull request**. `ci.yml` triggers on
`push: branches: [main]` and `pull_request`, so pushing a feature branch runs
nothing.

## Scope

- [ ] Single job `rust` on `ubuntu-latest`
- [ ] Order: `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
      `cargo test --locked`, then the retained checks, then the eval gates
- [ ] Node plugin tests retained minus the deleted npm wrapper test
- [ ] `check_version_bump.py` gated to `pull_request`

## Acceptance criteria

- [ ] On a pull request, a job named `rust` runs and passes
- [ ] The first three steps after checkout and toolchain setup are fmt, clippy, test, in that order
- [ ] `rg -n "cargo test --locked" .github/workflows/ci.yml` matches
- [ ] `rg -n "remem-runtime.test.js|request-security.test.js|server.test.js" .github/workflows/ci.yml` matches all three
- [ ] `rg -n "npm/remem" .github/workflows/ci.yml` returns nothing
- [ ] Introduce a deliberately failing unit test, push, and confirm the `rust` job fails on the `cargo test` step rather than an earlier gate; then revert it
