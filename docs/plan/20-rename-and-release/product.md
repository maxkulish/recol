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

One user, on one machine, with a small amount of state that matters and a large
amount that does not.

`recol status` against the live database reports Memories 0, Observations 0,
Sessions 0, Candidates 0, and Graph queue 0. There is no curated memory, no
feedback, no suppression, no workstream, and no graph state to lose. The 198 MB
is a raw archive of 22,555 messages, reproducible by re-running
`ingest-sessions` against transcripts still on disk.

Two things are not reproducible, and an earlier draft of this plan would have
destroyed both. The first is **extraction task id 1**, visible as `Extract fail:
1` and `Replay todo: 1`, produced from synthetic session
`manual-eval-1785099656`. It is the exact target of R1 step 2, which replays it
to classify the extraction failure as configuration or structural. Re-ingesting
transcripts does not recreate it. The second is `config.toml`, which records the
host, model, and reasoning selection.

So the cutover is recoverable rather than destructive: snapshot, export the two
artifacts that matter, verify the new installation answers representative
searches, move the old directory to a rollback location, and delete only after
that.

There are no other installations to keep compatible. No published package
carries the project's name, no downstream consumer imports it, and nothing in
`~/.claude/settings.json` or `~/.codex/config.toml` references it. There is no
integration to break, so the rename needs no compatibility layer and no
dual-read fallback.

## Why now, before R1

The rename touches `src/` broadly. Every roadmap item completed before it is one
more body of work the mechanical pass has to cross, and one more conflict
against it.

The CI argument is stronger. Today `ci.yml` is a single job in which `cargo
test` runs sixteenth, behind gates a detached repository cannot satisfy,
including a step replaying hardcoded issue GH813 and PR 906 commit SHAs. When
any of them fails, the Rust code is never compiled. R1 and R2 both specify
tests before implementation, and neither can rely on a gate that never reaches
the test suite.

## What changes

Six identity layers move from `remem` to `recol`: the crate and binary, the
`REMEM_*` environment variables, the data directory, the database and log
filenames, the Keychain service, and the plugin runtime manifest. The version
moves to **0.7.0**, because renaming the binary, the environment, and the data
path without a compatibility layer is a breaking change, and because
`check_version_bump.py` requires a bump for any `src/` change regardless.

Distribution narrows from five channels to two. GitHub Releases and a Homebrew
formula in the existing `maxkulish/homebrew-tap` replace crates.io, npm, and
MCP-registry publishing. `Cargo.toml` gains `publish = false`, so the abandoned
channel cannot be used by accident.

CI drops the heavy governance machinery: sensitive-governance, PR-tier
classification, closure-audit, spec-lifecycle, and their tests, along with both
`pull_request_target` workflows. It keeps the lightweight gates that still earn
their place: the PR preflight `AGENTS.md` mandates, version synchronization,
public-surface and public-claims retargeted to the new identity, file-size, and
the eval gates. The Rust steps run first. macOS coverage comes from hosted
runners, not a personal machine.

The repository gains the protection its release process assumes: branch
protection on `main`, a ruleset over `v*` tags, and a release environment
requiring approval.

## What stays

**`src/migrations/` is frozen for correctness.** `v010_ai_usage_token_breakdown.sql`
defaults `ai_usage_events.pricing_source` to `remem_static`,
`v011_reprice_ai_usage_events.sql` matches on `remem_static` and
`remem_static_backfill`, and `v063_procedure_exports.sql` declares a column
`remem_version`. Applied migrations are immutable by construction, so every
database they build carries those strings, including one created fresh after
the rename.

The freeze extends into `src/`, which an earlier draft got wrong. The same
literals appear in `src/db/usage.rs`, `src/ai/pricing.rs`,
`src/migrate/tests.rs`, `src/ai/tests.rs`, and `src/db/query/stats/tests.rs`,
and the `remem_version` column is read and written by
`src/memory/procedure/registry.rs` and emitted as an export key by
`src/memory/procedure/export/render.rs`. Renaming either side while the other
holds breaks the pricing lookup and the procedure export silently.

**Historical evidence is frozen**: `specs/`, the audits and analyses under
`docs/`, and `eval/`'s artifacts, meaning `golden.json`, the claims registry,
the locomo fixtures, and `eval/public/reports/`. Their condition IDs are
referenced by recorded results.

**LICENSE keeps `Copyright (c) 2026 majiayu000`.** This is a derivative work.
The MIT notice must ship with every copy, and the copyright line is preserved,
not rebranded.

Three things an earlier draft wrongly listed as frozen are renamed:

- **`site/`** is the public installation and marketing surface, not evidence.
  `check_public_surface.py` covers it by name. Freezing it would produce two
  contradictory product identities.
- **`eval/`'s executable scripts**, `run_local_eval.py` and `run_locomo.py`,
  invoke the binary and read `~/.remem/remem.db`. Freezing them breaks them.
- **`CHANGELOG.md`**, because the version-sync check requires its top section to
  match the Cargo version, and the version is changing.

## Done means

- `cargo fmt --check`, `cargo clippy`, and `cargo test` pass, and a rename audit
  reports zero occurrences outside an explicit allowlist of preserved literals
  and frozen paths.
- Version synchronization passes across `Cargo.toml`, `Cargo.lock`,
  `plugin.json`, the release manifest, and `CHANGELOG.md` at 0.7.0.
- CI runs the Rust gates first, retains the plugin runtime and app tests, and
  covers hosted Linux, ARM macOS, and Intel macOS. No self-hosted runner is
  registered.
- `main` is protected, `v*` tags are covered by a ruleset, and the release
  environment requires approval. A release preflight proves the tag points at
  the exact commit that passed CI on `main`.
- A first-run smoke under a temporary `HOME` and `RECOL_DATA_DIR` starts clean,
  and a plugin smoke with no repository binary and nothing matching on `PATH`
  downloads, verifies, installs, and starts the published runtime.
- Every release archive contains the binary and `LICENSE`. `brew audit` and
  `brew test` pass against the published formula.
- The old installation is in a rollback location with extraction task 1 and
  `config.toml` exported, and the new installation answers representative
  searches before anything is deleted.

## Explicitly out of scope

**Hooks stay.** The formula caveats are renamed to
`recol install --target codex|claude|all` and nothing else changes. An earlier
draft rewrote them to point at `recol doctor` on the grounds that SessionStart
and PostToolUse capture are rejected, which contradicted both `CLAUDE.md`'s
non-negotiable that automatic capture is the primary path and the plugin's
activation contract. Whether to remove hooks is an R7 decision with plugin and
runtime work attached; it is recorded there, not settled here.

Contributing R5 and R6 upstream now requires a fresh fork of
`majiayu000/remem`, since a detached repository cannot open a pull request
against its former parent. Noted as a consequence, not planned as work.
