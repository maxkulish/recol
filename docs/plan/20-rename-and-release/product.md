# R0 - Rename, CI refactor, and distribution

## The problem

This repository began as a GitHub fork of `majiayu000/remem` and inherited that
project's entire identity: its crate name, its binary, its 138 environment
variables, its on-disk footprint, its five publishing channels, and the CI
system built to govern a multi-contributor review process.

On 2026-07-27 the fork was detached. `maxkulish/recol` is now a standalone
repository with no GitHub parent. The `upstream` remote still fetches, so
cherry-picking upstream fixes continues to work, but the repository no longer
presents itself as somebody else's project with patches on top.

The name did not follow. Everything the project builds, ships, and writes to
disk still says `remem`, in 7,867 places across 898 files.

## Who has this problem

One user, on one machine, with no state worth preserving.

That last point is what makes this cheap. The 198 MB database at
`~/.remem/remem.db` is a test corpus, reproducible by re-running
`ingest-sessions` against the transcripts that are still on disk. The installed
`remem` binary came from crates.io and is not this project's build. Both can be
deleted rather than migrated.

There are no other installations to keep compatible. No published package
carries the project's name, no downstream consumer imports it, and nothing in
`~/.claude/settings.json` or `~/.codex/config.toml` references it, because
`remem install` was deliberately never run. There is no integration to break
and no data to strand, so the rename needs no compatibility layer, no dual-read
fallback, and no migration path.

## Why now, before R1

The rename touches `src/` broadly. Every roadmap item after this one adds code
to the same tree, so each one completed first is one more body of work the
rename has to pass through, and one more merge conflict against the mechanical
pass. Doing it first costs a day; doing it fifth costs the same day plus the
reconciliation.

The CI argument is stronger. Today `ci.yml` is a single job in which `cargo
test` runs sixteenth, behind fifteen governance gates that a detached
repository cannot satisfy: SpecRail wiring self-tests, PR-tier classification,
a sensitive-implementation gate, and a step replaying hardcoded issue GH813 and
PR 906 commit SHAs. When any of them fails, the Rust code is never compiled.
R1 and R2 both specify tests before implementation, and neither can rely on a
gate that never reaches the test suite.

## What changes

Six identity layers move from `remem` to `recol`: the crate and binary, the
`REMEM_*` environment variables, the data directory, the database and log
filenames, the Keychain service, and the plugin runtime manifest.

Distribution narrows from five channels to two. GitHub Releases and a Homebrew
formula in the existing `maxkulish/homebrew-tap` replace the inherited
crates.io, npm, and MCP-registry publishing, none of which the project has
credentials for or a reason to occupy.

CI drops the inherited governance layer, roughly 6,000 lines of Python serving
an issue and review process this repository does not run, and is rebuilt so the
Rust gates run first. A self-hosted M1 macOS runner joins it, restricted to
trusted triggers.

## What stays

Content the project inherited but does not author keeps the old name, because
renaming it would be churn that conflicts with every future cherry-pick and
rewrites documents describing decisions made under that name: `specs/`,
`eval/`, the audits and analyses under `docs/`, and `site/`.

`src/migrations/` is frozen for a stronger reason. `v011_reprice_ai_usage_events.sql`
writes the literal string `remem_static` into `ai_usage_events.pricing_source`,
and `v063_procedure_exports.sql` defines a column named `remem_version`.
Applied migrations are immutable by construction, so every database they build
carries those strings, including one created fresh after the rename. Renaming
inside them would diverge the schema from the Rust that reads it, and would do
so silently.

## Done means

- `cargo build`, `cargo test`, `cargo clippy`, and `cargo fmt --check` all pass
  on a tree where `rg -i remem` over live surfaces returns nothing.
- The crates.io `remem` binary and `~/.remem` are gone from the machine, and a
  fresh `recol ingest-sessions` run rebuilds the archive under the new paths.
- CI runs the Rust gates first and finishes without any inherited governance
  step, on hosted Linux for every trigger and on the M1 runner for trusted
  triggers only.
- Pushing a `v*` tag produces a GitHub Release with four platform tarballs and
  a `Formula/recol.rb` commit in `maxkulish/homebrew-tap`, with no attempt to
  publish to crates.io, npm, or the MCP registry.
- `brew install maxkulish/tap/recol` installs a working binary that reports
  `recol <version>`.

## Explicitly out of scope

Whether the project keeps hook-based host integration at all is an R7 question,
not a rename question. `plugins/` is renamed and left functional; its future is
decided later.

Contributing R5 and R6 upstream now requires a fresh fork of
`majiayu000/remem`, since a detached repository cannot open a pull request
against its former parent. That is noted here as a consequence, not planned as
work.
