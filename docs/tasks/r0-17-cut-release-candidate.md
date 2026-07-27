# R0-17 - Cut and verify a release candidate

Type: **HITL** | Blocked by: R0-15, R0-16 | Blocks: R0-18
Phase: 4 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 4)

## Goal

The whole release path is exercised against real artifacts, with the production
formula untouched.

## Context

This is the task that verifies R0-14, R0-15, and R0-16 against reality rather
than against a linter. Archive contents, checksum coverage, the staging
redirect, and the download smoke can only be proven by producing real assets.

**Retain the candidate.** Do not delete the tag, the release, or any asset. An
earlier draft deleted the test release after confirming the tap commit, which
would have stranded the formula on missing assets. Nothing referenced by a
formula, staging or production, is ever deleted.

The R0-04 tag ruleset blocks tag deletion, so this should be enforced as well as
documented. If a tag delete succeeds here, R0-04 is misconfigured.

## Scope

- [ ] Tag a release candidate, for example `v0.7.0-rc.1`
- [ ] Verify the four archives, checksums, and the staging formula
- [ ] Run the plugin download smoke against the candidate

## Acceptance criteria

- [ ] Four archives published: `recol-darwin-arm64`, `recol-darwin-x64`,
      `recol-linux-arm64`, `recol-linux-x64`
- [ ] `tar tzf` on **each** archive lists both `recol` and `LICENSE`
- [ ] The extracted `LICENSE` still reads `Copyright (c) 2026 majiayu000`
- [ ] `SHA256SUMS` covers all four, and each recorded hash matches a locally
      computed `shasum -a 256` of the downloaded archive
- [ ] The tap's **default branch is unchanged**: its `git log -1` is the same
      commit as before the candidate
- [ ] The tap's staging branch holds a `Formula/recol.rb` that passes `ruby -c`
- [ ] The R0-16 smoke exits 0 against the candidate's base URL
- [ ] The extracted binary reports `recol 0.7.0`
- [ ] Attempting `git push --delete origin v0.7.0-rc.1` is **refused** by the tag ruleset
