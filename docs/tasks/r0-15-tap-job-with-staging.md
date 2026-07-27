# R0-15 - Tap job with a staging dry-run

Type: **AFK** | Blocked by: R0-14 | Blocks: R0-17
Phase: 4 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 4)

## Goal

Release candidates can be exercised end to end without ever writing to the
formula real installations resolve.

## Context

The inherited job pushes `Formula/remem.rb` straight to
`majiayu000/homebrew-tap`. An earlier draft of this plan kept that behaviour for
a test release and then deleted the prerelease and its tag - which would have
left Homebrew pointing at assets that no longer exist. That is the failure this
task exists to prevent.

`maxkulish/homebrew-tap` already exists and is public, so no tap repository
needs creating.

**Caveats are renamed, not rewritten.** The inherited text instructs the user to
run `remem install --target codex|claude|all`; it becomes
`recol install --target codex|claude|all` and nothing else changes. An earlier
draft redirected it to `recol doctor` on the grounds that hook capture is
rejected, which contradicts `CLAUDE.md`'s non-negotiable that automatic capture
is the primary path. Removing hooks is an R7 decision with plugin and runtime
work attached, not a side effect of a caveats rewrite.

## Scope

- [ ] Prereleases render the formula to a **staging branch** of the tap and
      never to its default branch
- [ ] Production tags write `Formula/recol.rb` with `class Recol` to the default
      branch
- [ ] Checksums read from the release's `SHA256SUMS`, failing loudly if any of
      the four is missing
- [ ] Caveats renamed to `recol install --target codex|claude|all`
- [ ] `HOMEBREW_TAP_TOKEN` added to repository secrets, scoped to the tap only

## Acceptance criteria

- [ ] `ruby -c` on the rendered formula reports no syntax errors
- [ ] The rendered formula declares `class Recol` and four platform URLs under
      `github.com/maxkulish/recol/releases/download/`
- [ ] The caveats text contains `recol install --target` and does not contain
      `recol doctor` as the primary instruction
- [ ] A missing checksum fails the job rather than rendering a formula with an
      empty `sha256`
- [ ] Proven in R0-17: after the release candidate, the tap's default branch is
      unchanged and the staging branch holds the formula
