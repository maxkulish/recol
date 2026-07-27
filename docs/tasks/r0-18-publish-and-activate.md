# R0-18 - Publish the release and activate the plugin runtime

Type: **HITL** | Blocked by: R0-17 | Blocks: none
Phase: 4 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 4)

## Goal

`brew install maxkulish/tap/recol` installs a working `recol`, and the plugin
resolves its runtime from the published release.

## Context

**The manifest transition is the step that is easy to forget and breaks the
plugin silently.** `recol-runtime.js:359` returns `null` while the checked-in
manifest says `state: "unreleased"`, before it ever consults a base URL. So
publishing the release is not sufficient: a follow-up commit must update the
repository's `recol-releases.json` with the published base URL and checksums.
R0-16's smoke is what proves it took effect.

Homebrew's own guidance is that formulae carry both a test and an audit, so both
run here rather than being assumed from the candidate.

Ordering matters: publish, then commit the manifest, then run the smoke. Running
the smoke before the manifest commit will correctly fail.

## Scope

- [ ] Tag and publish `v0.7.0` through the `release` environment approval
- [ ] Commit the post-release manifest update with base URL and checksums
- [ ] Verify the production formula, audit, test, and a clean install
- [ ] Re-run the plugin download smoke against production

## Acceptance criteria

- [ ] The release is published with four archives and `SHA256SUMS`
- [ ] The tap's default branch now holds `Formula/recol.rb` at 0.7.0, passing `ruby -c`
- [ ] `rg -n '"state"' plugins/recol/runtimes/recol-releases.json` no longer shows `unreleased`, and the file carries a `base_url` and per-platform checksums
- [ ] `brew audit --strict maxkulish/tap/recol` exits 0
- [ ] `brew test recol` exits 0
- [ ] On a machine with no prior installation, `brew install maxkulish/tap/recol` succeeds and `recol --version` prints `recol 0.7.0`
- [ ] The R0-16 smoke exits 0 with **no repository binary and nothing matching `recol` on `PATH`**
- [ ] The R0-17 release candidate and its assets are still present
