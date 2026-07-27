# R0-14 - Rewrite release.yml for two channels

Type: **AFK** | Blocked by: R0-04, R0-10 | Blocks: R0-15
Phase: 4 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 4)

## Goal

Tagging produces four platform archives that each carry the licence, built from
a commit proven to have passed CI, behind a human approval.

## Context

`release.yml` currently runs five publish jobs behind a preflight requiring
three secrets, all under upstream's identity. Three of those channels are
abandoned.

**Archives are missing the licence.** Line 84 is `tar czf ... remem` - the
binary alone. `LICENSE` is MIT, `Copyright (c) 2026 majiayu000`. This is a
derivative work: the notice must ship with every copy, and the copyright line is
**preserved**, not rebranded. This is a legal obligation, not hygiene.

**Deleting `auto-release.yml` removes real guarantees.** It carried the only
exact-main-SHA verification and immutable-tag handling. Immutability moves to
the R0-04 tag ruleset; the SHA check moves here, into the preflight.

`check_release_workflows.py` is retained and must keep passing. Inspect what it
asserts before restructuring, and update it in this commit if it constrains the
old shape.

## Scope

- [ ] Preflight requires `HOMEBREW_TAP_TOKEN` only
- [ ] Preflight proves the tag commit is the exact commit that passed CI on
      `main`
- [ ] Publishing jobs reference the `release` environment
- [ ] Matrix: `aarch64-apple-darwin` on `macos-15`, `x86_64-apple-darwin` on
      `macos-15-intel` with `--no-default-features`, both Linux targets on
      `ubuntu-latest`, all with `--locked`
- [ ] Archives contain the binary **and** `LICENSE`; artifacts renamed to
      `recol-{darwin,linux}-{arm64,x64}`
- [ ] Delete `publish-crate`, `publish-npm`, `publish-mcp-registry`,
      `.github/workflows/auto-release.yml`,
      `scripts/ci/auto_release_check_tag_state.sh`
- [ ] Rewrite `docs/release-lifecycle.md` for tag-driven, two-channel releases

## Acceptance criteria

- [ ] `python3 scripts/ci/check_release_workflows.py` exits 0
- [ ] `rg -n "CRATES_IO_TOKEN|NPM_TOKEN|publish-crate|publish-npm|publish-mcp-registry" .github/workflows/` returns nothing
- [ ] `ls .github/workflows/auto-release.yml scripts/ci/auto_release_check_tag_state.sh` fails for both
- [ ] `rg -n "environment:\s*release" .github/workflows/release.yml` matches every publishing job
- [ ] `rg -n "LICENSE" .github/workflows/release.yml` matches inside the packaging step
- [ ] `rg -n "macos-15-intel" .github/workflows/release.yml` matches, and `rg -n "macos-latest" .github/workflows/release.yml` returns nothing
- [ ] `actionlint .github/workflows/release.yml` reports no errors
- [ ] Archive contents are proven in R0-17, which asserts `tar tzf` lists both the binary and `LICENSE`
