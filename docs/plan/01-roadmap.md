# Recol - Roadmap

Ordered by dependency, not by value.

Each item carries a classification, which under the divergence assumption in
`README.md` reads as "would this stand alone if offered upstream" rather than a
commitment to offer it. R5 and R6 are the two that genuinely would.

Status legend: `blocked`, `next`, `queued`, `done`.

---

## R0 - Rename, CI refactor, and distribution

Status: **next** | Classification: **fork** | Blocks: R1, and every item after
it | Spec: `20-rename-and-release/`

On 2026-07-27 the GitHub fork was detached, so `maxkulish/recol` is a
standalone repository with no parent. The name did not follow: the crate,
binary, 138 environment variables, on-disk paths, and five publishing channels
all still say `remem`.

Sequenced first for two reasons. The rename touches `src/` broadly, so every
item completed before it is one more body of work the mechanical pass has to
cross. More importantly, `ci.yml` today runs `cargo test` sixteenth, behind
fifteen inherited governance gates that a detached repository cannot satisfy,
including a step replaying hardcoded GH813 and PR 906 commit SHAs. When any of
them fails the Rust code is never compiled, and R1 and R2 both specify tests
before implementation.

Five phases: trim governance to the gates that still earn their place and add
the branch, tag, and environment protection the repository lacks; rebuild CI so
the Rust gates run first across hosted Linux, ARM macOS, and Intel macOS; rename
the live surfaces under a manifest with a preserved-literal allowlist; perform a
recoverable local cutover; and narrow distribution to GitHub Releases plus
`maxkulish/homebrew-tap`.

`src/migrations/`, `specs/`, `eval/`'s artifacts, and the audits under `docs/`
keep the old name. The migrations are frozen for correctness: `v010` and `v011`
bind `remem_static` and `remem_static_backfill` in
`ai_usage_events.pricing_source`, and `v063` declares a column `remem_version`
that `src/memory/procedure/registry.rs` reads and writes. Those literals are
preserved in `src/` too, and the rename audit asserts they survive.

`site/`, `eval/`'s executable scripts, and `CHANGELOG.md` are renamed, not
frozen: the first is a checked public surface, the second invoke the binary, and
the third is version-synchronized.

One consequence to record: a detached repository cannot open a pull request
against its former parent, so the `upstream` classification on R5 and R6 now
describes intent rather than an available route. Cherry-picking from the
`upstream` remote is unaffected.

---

## R1 - Reliable extraction output

Status: **blocked** on R0 | Classification: **upstream-after** | Blocks: R2,
and any evaluation of curation quality

The first real extraction failed with `malformed observation_extract output:
expected strict JSON object`. Output is parsed by a bare
`serde_json::from_str(output.trim())` in
`src/observation_extract/response.rs:44` with no schema enforcement, no fence
stripping, no repair, and no persistence of the raw output on failure.

Work, in order:

1. Persist the raw model output on parse failure. Without this every future
   failure is undiagnosable, and it is a few lines. Do this first regardless of
   what causes the current failure.
2. Re-run the failed range at higher reasoning and on a larger model to
   establish whether this is a configuration problem or a structural one:
   `remem worker --replay-range-id 1` after
   `remem model use gpt-5.6-luna --host codex-cli --reasoning medium`, then
   again with `gpt-5.6-terra`.
3. Add a defensive repair pass before the strict parse: strip markdown fences,
   take the outermost balanced JSON object, then parse. Cheap, and correct even
   when the model behaves.
4. If failures persist, the fix is schema enforcement, which `codex exec` cannot
   provide. That escalates into R4.

Upstream classification is `upstream-after`: steps 1 and 3 are unambiguously
useful to everyone and should go up once validated. Step 4 is a larger design
change.

Note the presets ship as `gpt-5.4-mini` and `gpt-5.2`, both superseded. Current
OpenAI models are `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`. A stale
preset list is itself a small upstream PR.

---

## R2 - Transcript-to-curation bridge

Status: **blocked** on R1 | Classification: **fork** | Spec:
`10-transcript-bridge/`

The central feature. Promote `source=transcript` rows from the raw archive into
the extraction pipeline, so the existing corpus produces curated decisions
rather than only raw search hits.

Blocked on R1 because a bridge feeding an unreliable extractor cannot be
evaluated: every bad memory would be ambiguous between a bridge defect and an
extraction defect.

See the spec directory for product, tech, and tasks.

---

## R3 - Per-project sensitivity routing

Status: **queued** | Classification: **fork**, with a possible upstream subset

Route extraction by project sensitivity, so private projects use a local model
and never egress. Upstream routes by host, not by project.

All routing funnels through `resolve_memory_ai_profile(selection:
MemoryAiSelection)` in `src/runtime_config.rs:213`, where `MemoryAiSelection`
carries `host` and `profile`. The change is a project dimension on that struct,
a project-to-profile map in the config, and a resolution branch consulted before
the host fallback. Contained, because there is one resolution site.

The general mechanism (per-project profile override) is plausibly an upstream
contribution. The specific sensitivity semantics, including a hard refusal to
egress for projects marked private, is fork-shaped.

Depends on a local executor existing, which today it does not: executors are
`Http` (Anthropic only), `ClaudeCli`, and `CodexCli`. See R4.

---

## R4 - Backend layer replacement

Status: **queued** | Classification: **fork**

Replace `src/ai/` with the backend crate being extracted from `lok`, which
provides claude, codex, gemini, ollama and bedrock behind one async trait with
health probes and hardened Codex event parsing.

Delivers three things at once: an Ollama path, which is what R3 needs; direct
HTTP against OpenAI with a real API key rather than inheriting the Codex CLI's
auth; and the ability to send `response_format` with a JSON schema, which is
what R1 step 4 needs.

Depends on the lok extraction, tracked outside this repository at
`~/.claude/handoffs/2026-07-26-lok-extract-backend-lib.md`.

Cost note motivating this beyond correctness: a trivial `remem model test
--live` consumed 12,627 tokens, of which 8,960 were cache reads of codex's own
agent system prompt. That scaffolding is paid on every invocation. Over a
corpus-scale backfill it dominates the bill, and a direct API call avoids it
entirely.

---

## R5 - Retrieval fixes

Status: **queued** | Classification: **upstream**

Three independent, small changes, each shippable alone. None depend on R1-R4,
so they can be done at any time and are good first PRs to test whether upstream
accepts contributions.

**R5a - relevance ordering.** `search_raw_messages` in
`src/memory/raw_archive.rs:528` ends with `ORDER BY r.created_at_epoch DESC`
despite joining an FTS5 index that computes BM25. On the reference gold set this
cost a correct answer: a query for an rs-wisper topic returned two newer
investigations messages that merely mentioned it.

**R5b - short tokens.** `fts_query` at `src/memory/raw_archive.rs:780` wraps
each term as a quoted phrase against a trigram tokenizer, so terms under three
characters cannot match. `yq` returns zero hits on a corpus that contains it.

**R5c - project attribution without git.** Ingestion shells out to
`git rev-parse --show-toplevel` in the transcript's recorded directory, which
fails for every merged worktree: 193 errors on the reference corpus. Every
`assistant` and `user` record already carries `cwd` and `gitBranch`, so the
information is in the file and does not need a subprocess.

---

## R6 - Key source

Status: **queued** | Classification: **upstream**

`load_cipher_key()` in `src/db/crypto.rs:36` checks `REMEM_CIPHER_KEY` then
falls back to a `0600` file beside the database. Add a key source resolving from
macOS Keychain or a secret manager, inside that function, so the key never
enters the process environment.

The environment path has a concrete flaw worth stating in the PR: remem spawns
`codex` and `claude` as subprocesses, which inherit the parent environment, so
`REMEM_CIPHER_KEY` is visible inside every AI subprocess it launches.

One function, one call site, self-contained. The best candidate for the first
upstream PR.

---

## R7 - Retrieval triggering

Status: **queued** | Classification: **fork**

The mechanism that decides whether a pull-based tool is used at all. A skill
matched on discovery intent, a slash command, and a `check <scope>` subcommand
cheap enough to run from a gate at plan-mode entry or first edit, reporting that
prior decisions exist without injecting their content.

Instrument trigger rate and use rate from the start, because an unused tool and
a tool with nothing to say are indistinguishable from outside.

Design is settled; see `~/Work/investigations/recol/2026-07-26-retrieval-triggering.md`.
Sequenced last because it is worthless until R2 has populated memories worth
triggering on.

---

## Dependency graph

```
R0 (rename, CI, distribution)
 └─> R1 (extraction reliability)
      └─> R2 (transcript bridge)  ──> R7 (triggering)
R4 (backend swap) ──> R3 (sensitivity routing)
   └─ also unblocks R1 step 4 if the failure is structural
R5 (retrieval fixes)  independent of R1-R4, after R0
R6 (key source)       independent of R1-R4, after R0
```

R0 precedes everything because it rewrites `src/` and because it is what makes
CI reach `cargo test` at all. R5 and R6 remain the cheapest wins once it lands,
and are the only two items that would stand alone if offered upstream, though
doing so now needs a fresh fork.

R6 is worth noting against R0: it adds the Keychain key source that the
workstation currently fakes with a `.zshrc` wrapper. After R0 that wrapper reads
`recol-cipher-key`, and R6 replaces it by teaching `load_cipher_key()` to read
the same entry directly.
