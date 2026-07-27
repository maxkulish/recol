# R0-03 - Delete npm/ and server.json, narrow version sync

Type: **AFK** | Blocked by: none | Blocks: R0-05
Phase: 0 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 0)

## Goal

The two package manifests with no publish target are gone, and version
synchronization checks only the sources that still ship.

## Context

Distribution narrows to GitHub Releases and Homebrew, so `npm/remem/`
(`@remem-ai/remem`) and `server.json` (`io.github.majiayu000/remem`) have
nothing to publish to.

`scripts/ci/check_plugin_version_sync.py` currently reads six sources:
`Cargo.toml`, `Cargo.lock` (keyed on `remem-ai`), `plugin.json`, `npm_version()`,
`server.json`, and `CHANGELOG.md` (lines 188-202). Removing two sources means
editing the reader **and** the error strings at lines 248 and 257, which name
npm and `server.json` explicitly.

Four sources survive: `Cargo.toml`, `Cargo.lock`, `plugin.json`, the release
manifest, and `CHANGELOG.md`. Do not narrow further - `CHANGELOG.md` in
particular must stay, because R0-09 bumps the version and the check enforces
that its top section matches.

Independent of the governance trim, so this can be done before, after, or
alongside R0-01 and R0-02.

## Scope

- [ ] Delete `npm/` and `server.json`
- [ ] Remove the npm and `server.json` sources from
      `check_plugin_version_sync.py`, including their error messages
- [ ] Remove the npm test step and npm publish job references from workflows
- [ ] Leave `Cargo.lock`, `plugin.json`, release manifest, and `CHANGELOG.md`
      checks intact

## Acceptance criteria

- [ ] `ls npm server.json` fails for both paths
- [ ] `python3 scripts/ci/check_plugin_version_sync.py` exits 0
- [ ] `rg -n "npm|server\.json" scripts/ci/check_plugin_version_sync.py` returns nothing
- [ ] `rg -n "npm/|server\.json|NPM_TOKEN" .github/workflows/` returns nothing
- [ ] `rg -c "CHANGELOG" scripts/ci/check_plugin_version_sync.py` returns at least 1
- [ ] `cargo test --workspace` exits 0
