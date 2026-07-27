# Recol - Task Board

Working task list for the fork. Authoritative planning lives in `docs/plan/`;
this file is the tracking view of it, mirroring the session task list.

Roadmap source: `docs/plan/01-roadmap.md`. Status legend: `next`,
`in progress`, `blocked`, `queued`, `done`.

## Tasks

| # | Item | Status | Blocked by | Class | Spec |
|---|------|--------|-----------|-------|------|
| 12 | R0 - Rename, CI refactor, distribution | next | - | fork | `docs/plan/20-rename-and-release/` |
| 1 | R1 - Reliable extraction output | blocked | 12 | upstream-after | `docs/plan/01-roadmap.md` (R1) |
| 2 | R2 - Transcript-to-curation bridge | blocked | 1 | fork | `docs/plan/10-transcript-bridge/` |
| 3 | R3 - Per-project sensitivity routing | blocked | 4 | fork | `docs/plan/01-roadmap.md` (R3) |
| 4 | R4 - Backend layer replacement | queued | 12 | fork | `docs/plan/01-roadmap.md` (R4) |
| 5 | R5 - Retrieval fixes (a, b, c) | queued | 12 | upstream | `docs/plan/01-roadmap.md` (R5) |
| 6 | R6 - Key source (Keychain) | queued | 12 | upstream | `docs/plan/01-roadmap.md` (R6) |
| 7 | R7 - Retrieval triggering | blocked | 2 | fork | `docs/plan/01-roadmap.md` (R7) |

## Dependency graph

```
R0 (rename, CI, distribution)
 └─> R1 (extraction reliability)
      └─> R2 (transcript bridge) ──> R7 (triggering)

R4 (backend swap)
 └─> R3 (sensitivity routing)
 └─ also unblocks R1 step 4 if the extraction failure is structural

R5 (retrieval fixes)   independent of R1-R4, after R0
R6 (key source)        independent of R1-R4, after R0
```

R0 comes first because it rewrites `src/` broadly and because it is what makes
CI reach `cargo test` at all. R5 and R6 remain the cheapest wins once it lands.

## Detail

### 12. R0 - Rename, CI refactor, distribution

The GitHub fork was detached on 2026-07-27, so this is a standalone repository
whose crate, binary, 138 environment variables, on-disk paths, and five
publishing channels all still carry the old name.

Five phases, each a branch merged through a pull request, in dependency order:

- **P0 Governance trim and protection.** Delete the heavy machinery
  (sensitive-governance, PR-tier, closure-audit, spec-lifecycle, both
  `pull_request_target` workflows, `checks/`, root SpecRail config, `npm/`,
  `server.json`). Keep the lightweight gates, including `check_pr_preflight.py`,
  which `AGENTS.md:89` mandates. Update `AGENTS.md` and the PR template in the
  same commit. Configure branch protection, a `v*` tag ruleset, and a `release`
  environment, none of which exist today.
- **P1 CI rebuild.** Three hosted jobs. Rust gates first on `ubuntu-latest`,
  plus `macos-15` (ARM64) and `macos-15-intel`. No self-hosted runner: hosted
  ARM macOS exists, so attaching a personal machine holding the database
  Keychain key to a public repo is unnecessary.
- **P2 Rename.** Manifest-driven pass with a preserved-literal allowlist and a
  rename audit written before the rename. Version moves to 0.7.0 with
  `publish = false`.
- **P3 Recoverable cutover.** Inventory, export extraction task 1 and
  `config.toml`, snapshot, verify the new install answers searches, and only
  then retire the old directory and Keychain entry.
- **P4 Release, staged then published.** RC never touches the production tap.
  Archives carry `LICENSE`. A post-release commit flips the plugin manifest out
  of `state: "unreleased"`, which otherwise blocks remote resolution.

Frozen for correctness, not preference. `v010` and `v011` bind
`remem_static` / `remem_static_backfill`, and `v063` declares column
`remem_version`. The freeze extends into `src/`: the same literals live in
`src/db/usage.rs`, `src/ai/pricing.rs`, `src/memory/procedure/registry.rs`, and
`src/memory/procedure/export/render.rs`. Renaming one side and not the other
breaks pricing lookup and procedure export silently.

### 1. R1 - Reliable extraction output

Make `observation_extract` parsing diagnosable and resilient. Ordered work:

1. Persist the raw model output when the parse fails at
   `src/observation_extract/response.rs:44`. Today `extraction_tasks.last_error`
   holds only the message, truncated to 2000 chars by
   `src/db/extraction/lifecycle.rs:379`; the model output itself is lost, so
   every retry reports only *that* it failed.
2. Replay failed range id 1 to classify configuration vs structural:
   `remem model use gpt-5.6-luna --host codex-cli --reasoning medium`, then
   `remem worker --replay-range-id 1`; repeat with `gpt-5.6-terra`.
3. Add a defensive repair pass before the strict parse: strip markdown fences,
   take the outermost balanced JSON object, then parse strictly.
4. If failures persist the fix is schema enforcement, which `codex exec` cannot
   provide. That escalates into R4.

Also noted: the shipped presets `gpt-5.4-mini` and `gpt-5.2` are both
superseded. Refreshing them is a small upstream PR on its own.

### 2. R2 - Transcript-to-curation bridge

The central fork feature. Promote `source=transcript` rows from the raw archive
into the extraction pipeline, so the existing 22,555-message corpus produces
curated decisions rather than only raw search hits.

Read `src/ingest/session_identity.rs` and `src/session_rollup/raw_identity.rs`
before writing code - both already map archived transcripts to identity, and the
mapping the bridge needs may already exist.

Blocked on R1 because a bridge feeding an unreliable extractor cannot be
evaluated: every bad memory would be ambiguous between a bridge defect and an
extraction defect.

### 3. R3 - Per-project sensitivity routing

Route extraction by project sensitivity so private projects use a local model
and never egress. Upstream routes by host, not by project.

All routing funnels through `resolve_memory_ai_profile(selection:
MemoryAiSelection)` in `src/runtime_config.rs:213`. The change is a project
dimension on that struct, a project-to-profile map in config, and a resolution
branch consulted before the host fallback. Contained, because there is one
resolution site.

Blocked on R4: needs a local executor, which does not exist today. Executors are
`Http` (Anthropic only), `ClaudeCli`, and `CodexCli`.

### 4. R4 - Backend layer replacement

Replace `src/ai/` with the backend crate being extracted from `lok`: claude,
codex, gemini, ollama and bedrock behind one async trait, with health probes and
hardened Codex event parsing.

Delivers three things at once: the Ollama path R3 needs, direct HTTP against
OpenAI with a real API key instead of inheriting the Codex CLI's auth, and
`response_format` with a JSON schema, which R1 step 4 needs.

Depends on the lok extraction, tracked at
`~/.claude/handoffs/2026-07-26-lok-extract-backend-lib.md`.

Cost motivation beyond correctness: a trivial `remem model test --live` consumed
12,627 tokens, 8,960 of them cache reads of codex's own agent system prompt.
That scaffolding is paid on every invocation and would dominate a corpus-scale
backfill.

### 5. R5 - Retrieval fixes

Three independent changes, each shippable alone.

- **R5a - relevance ordering.** `search_raw_messages` in
  `src/memory/raw_archive.rs:528` ends with `ORDER BY r.created_at_epoch DESC`
  despite joining an FTS5 index that computes BM25. On the reference gold set
  this cost a correct answer.
- **R5b - short tokens.** `fts_query` at `src/memory/raw_archive.rs:780` wraps
  each term as a quoted phrase against a trigram tokenizer, so terms under three
  characters cannot match. `yq` returns zero hits on a corpus containing it.
- **R5c - project attribution without git.** Ingestion shells out to
  `git rev-parse --show-toplevel` in the transcript's recorded directory, which
  fails for every merged worktree: 193 errors on the reference corpus. Every
  `assistant` and `user` record already carries `cwd` and `gitBranch`.

### 6. R6 - Key source

`load_cipher_key()` in `src/db/crypto.rs:36` checks `REMEM_CIPHER_KEY` then
falls back to a `0600` file beside the database. Add a key source resolving from
macOS Keychain or a secret manager inside that function, so the key never enters
the process environment.

The flaw worth stating in the PR: remem spawns `codex` and `claude` as
subprocesses, which inherit the parent environment, so `REMEM_CIPHER_KEY` is
visible inside every AI subprocess it launches.

One function, one call site, self-contained. The best candidate for a first
upstream PR.

### 7. R7 - Retrieval triggering

The mechanism that decides whether a pull-based tool is used at all: a skill
matched on discovery intent, a slash command, and a `check <scope>` subcommand
cheap enough to run from a gate at plan-mode entry or first edit, reporting that
prior decisions exist without injecting their content.

Instrument trigger rate and use rate from the start, because an unused tool and
a tool with nothing to say are indistinguishable from outside.

Design is settled in
`~/Work/investigations/recol/2026-07-26-retrieval-triggering.md`. Sequenced last
because it is worthless until R2 has populated memories worth triggering on.

## Working constraints

These are established, not open questions. Re-deriving them wastes a session.

- **The installed `remem` on PATH is crates.io 0.6.27, not this build.** Testing
  changes needs `cargo run --` or `cargo install --path .`, otherwise you are
  exercising upstream and will conclude your change did nothing. R0 phase 3
  removes it.
- **The database holds no curated state, but two things in it are not
  reproducible.** `status` reports Memories 0, Observations 0, Sessions 0,
  Candidates 0, Graph queue 0, so the 22,555-message archive is rebuildable by
  re-running `ingest-sessions`. Extraction task id 1 (`Extract fail: 1`) and
  `config.toml` are not: task 1 is R1 step 2's replay target. Export both before
  any cutover.
- **The repository is detached from `majiayu000/remem`.** Cherry-picking from
  the `upstream` remote still works; opening a pull request against it does
  not, and would need a fresh fork.
- **`ingest-sessions` does not feed curation.** Verified in source and
  empirically: 1,900 files and 22,555 messages ingested produced Captured 0,
  Extract todo 0, Candidates 0. The pipelines are separate by design; this is
  the reason the fork exists.
- **Diagnose search quality with `--json`, reading `.results[].content`.** The
  CLI's printed output shows only the first line of each message as a preview,
  which once made four unrelated queries look identical.
- **Commands need the cipher key in the environment at invocation time.** A
  shell function supplies `REMEM_CIPHER_KEY` from Keychain interactively; a
  fresh agent shell does not, and the failure reads as "refusing to open remem
  database without a SQLCipher key".
- **Do not run `remem install`.** It wires SessionStart injection and PostToolUse
  capture into Claude Code, which the design rejects, and starts background
  curation automatically.
- **Do not use gcm as the base for the shared backend crate.** Measured and
  rejected: `src/provider/*.rs` references `crate::plan` and `crate::diff` seven
  times each, so its trait is commit-shaped. lok is the base.
- **Do not trust `remem usage` for extraction cost.** It recorded a text-length
  estimate rather than provider data, and says so itself. Treat projections
  built on it as a lower bound.
