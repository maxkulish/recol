# Recol - Product Brief

Status: draft, 2026-07-26. Supersedes nothing; this is the fork's founding
document.

## 1. The problem

Each new coding task starts blank. Decisions made in earlier tasks, and the
reasoning behind them, are gone by the time the next task begins, so context
gets re-described from scratch and settled questions get re-litigated.

The unit of loss is not code and not facts. It is **decisions plus their
rationale**, including the options considered and rejected. The moment of loss
is the start of the next task in a sequence.

The knowledge was produced. It was discussed, acted on, and then never written
anywhere that survives the session. What does survive is the raw transcript:
roughly 777 MB across 1,900 files on the reference machine, of which about 20%
is reasoning content and the rest is tool output.

## 2. Why a fork rather than a new tool, or upstream as-is

Upstream `remem` already provides almost everything needed: a curation pipeline
that turns captured activity into memories with rationale, multi-channel RRF
retrieval with score explanation, candidate review, governance and deletion,
staleness handling, token accounting, and both CLI and MCP surfaces. Roughly
270,000 lines and 3,144 tests.

It also already ingests raw transcripts. `remem ingest-sessions` scans
`~/.claude/projects` and `~/.codex/sessions` and fills a searchable raw archive.
On the reference corpus it processed 1,900 files and 22,555 messages with zero
failures.

**But the raw archive does not reach the curation pipeline.** Ingested rows
carry `source=transcript`, which is consumed nowhere outside `raw_archive.rs`
and test fixtures. Curation is fed by `captured_events`, written by hooks during
live sessions. Verified empirically: after ingesting 1,900 files, the capture
pipeline reported Captured 0, Extract todo 0, Candidates 0, and
`remem worker --once` made no model calls at all.

So upstream gives you a well-indexed grep over your history and a decision
memory over your future. The history stays raw. Closing that gap is the reason
this fork exists, and it is one bridge against an otherwise complete pipeline -
which is a far better position than rebuilding the pipeline.

## 3. Users

One engineer, working across roughly 34 logical projects on one machine, with a
second machine expected. Projects range from code repositories to personal
material including health, finance, and property records, plus employer work.
That range is why data routing is a product requirement and not a setting.

## 4. What this fork changes

**Fork-only, because upstream has chosen otherwise or it depends on fork
capability:**

- Promote archived transcripts into the curation pipeline, so existing history
  produces curated decisions rather than only raw search hits.
- Per-project sensitivity routing: a private project's content is extracted by a
  local model and never leaves the machine, while code repositories may use a
  cloud provider. Upstream routes by *host*, not by project sensitivity.
- No forced context injection. Upstream installs a SessionStart hook that
  injects memories into every session. This fork keeps retrieval pull-based: a
  cheap existence check may report that prior decisions touch a scope, but
  content enters context only when queried.

**Upstream candidates, developed here and offered back:**

- A key source that resolves the SQLCipher key from macOS Keychain or a secret
  manager, inside `load_cipher_key()`, so it never enters the process
  environment where spawned AI subprocesses inherit it.
- Relevance ordering in raw search. `search_raw_messages` ends with
  `ORDER BY r.created_at_epoch DESC` despite FTS5 computing a BM25 score.
- Short-token search. The trigram tokenizer silently returns nothing for terms
  under three characters, so `yq`, `jq`, `rg`, `fd`, `op`, and `gh` never match.
- Schema-enforced extraction output. See section 5.
- Project attribution from the transcript's recorded `cwd` rather than shelling
  out to `git` in a directory that may have been deleted. On the reference
  corpus this produced 193 errors, all in merged worktrees - which are exactly
  the task branches where decisions were made.

## 5. The open reliability question

The first real extraction run failed: `malformed observation_extract output:
expected strict JSON object`.

The cause is structural. Extraction output is parsed with a bare
`serde_json::from_str(output.trim())`. There is no `response_format`, no
`json_schema`, no fence stripping, no repair pass, and the raw model output is
not persisted on failure so it cannot be inspected. Provider-level structured
output is not used anywhere in the codebase.

It cannot be, while extraction runs through `codex exec`. An agent CLI does not
expose `response_format`.

Two possible resolutions, and the measurement deciding between them is in
flight:

- If raising reasoning effort or changing model fixes it, this is a stale-preset
  problem and the fix is configuration plus a defensive repair pass.
- If it persists, extraction is unreliable on current models by construction,
  and the fix is a direct HTTP path that can enforce a schema.

This blocks meaningful evaluation of the bridge, because a bridge that feeds an
unreliable extractor produces unreliable memories. It is therefore sequenced
first in the roadmap.

## 6. Success criteria

Measured, not asserted. The reference gold set is ten questions whose answers
are known from memory; the baseline scored roughly 6.5 of 10 on raw search with
recency ordering and no curation.

| Criterion | Target | How measured |
|---|---|---|
| Extraction reliability | Zero malformed-output failures across 100 consecutive extractions | Worker logs |
| Recall | Recall@5 above 0.80 on the gold set | Gold-set harness, adopted from the Mentis eval design |
| Rationale, not summary | A curated memory states the decision and its reason in one line for at least 8 of 10 gold questions | Manual read |
| Supersession | Querying a decision that was later reversed returns the current decision, with the superseded one marked, never as guidance | The reversal test |
| Data routing | Zero network calls attributable to a project marked private | Provider call log per project |
| History coverage | Curated memories exist for tasks completed before the fork was installed | Query a pre-fork decision |

The last row is the one that distinguishes this fork from upstream. If it fails,
the fork has no reason to exist.

## 7. Non-goals

- Rebuilding the curation pipeline, retrieval, governance, or MCP surface.
  These work; the fork's value is the bridge and the routing.
- Diverging from upstream where upstream would accept the change. Every item is
  classified before work starts, and the default is upstream.
- SessionStart digest injection. Deliberately rejected; see section 4.
- Multi-user or hosted operation. Local-first, single operator.
