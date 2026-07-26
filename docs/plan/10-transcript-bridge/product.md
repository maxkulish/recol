# R2 Product Spec: promote archived transcripts into curation

Classification: **fork**. Depends on R1 (reliable extraction output).

## 1. Background

`remem ingest-sessions` fills a raw archive from `~/.claude/projects` and
`~/.codex/sessions`. On the reference machine that is 1,900 files and 22,555
messages, ingested with zero failures into a 198 MB database, carrying correct
project, branch, cwd, role and timestamp attribution on every row.

Curation - the step that turns activity into memories with rationale - is fed by
`captured_events`, written by hooks during live sessions. Rows from ingestion
carry `source=transcript` and are read only by raw search.

The two pipelines never meet. After ingesting 1,900 files the capture pipeline
reported Captured 0, Extract todo 0, Candidates 0, and `remem worker --once`
made no model calls.

## 2. Problem

A user who installs the tool today gets curated decisions for work they do
*from now on*, and raw text search over everything they did before. The
knowledge they most want - why the current design is the way it is - lives
almost entirely in the past.

Raw search does recover the right sessions much of the time: on a ten-question
gold set with known answers it put the right project in the top two for roughly
6.5 of 10. But every hit is a whole chat turn beginning "Done. Here's the
summary...", so the user reads a conversation to find a decision. That is better
than nothing and it is not a decision memory.

## 3. Who has this problem

Anyone adopting the tool with existing history, which is everyone who has been
using an agent CLI for more than a few weeks. The reference user has 34 logical
projects and roughly 152 MB of reasoning content accumulated before installing
anything.

## 4. Proposal

Add a path that promotes archived transcript rows into the same extraction
pipeline that hook-captured events use, so history produces curated memories
through the existing, tested machinery.

Explicitly reuse the pipeline rather than building a parallel one. The
extraction, candidate review, governance and retrieval stages all work; the gap
is upstream of them.

The promotion is user-initiated and bounded. It is not automatic on ingest,
because extraction costs money and touches every project including private
ones, and both of those are decisions the user must make per project rather than
implicitly.

## 5. Acceptance

1. A user can promote one named project's archived transcripts and see curated
   memories appear for it, with no hooks installed.
2. Promotion is bounded by project, by time range, and by a limit, so a first
   run can be small and cheap.
3. Promotion is idempotent. Running it twice over the same range does not
   produce duplicate memories or duplicate spend.
4. Promoted memories are distinguishable from hook-captured ones by
   provenance, so a user can tell where a decision came from and delete a bad
   backfill without touching live capture.
5. A dry run reports how many events would be promoted and an estimated token
   cost, before anything is spent.
6. Querying a decision made before the tool was installed returns a curated
   memory stating the decision and its reason. This is the criterion the fork
   exists for; the others are hygiene.

## 6. Out of scope

- Changing the extraction prompt or the memory schema. If promoted transcripts
  need a different prompt than hook events, that is a finding for a later
  iteration, not an assumption to build in now.
- Automatic promotion on ingest. See section 4.
- Deduplicating a decision that appears in many sessions. Real and worth doing,
  but it belongs in a consolidation pass above extraction, not in the bridge.
- Backfilling the full corpus. The bridge makes it possible; whether to spend
  that is a separate decision informed by the dry-run estimate.

## 7. Risks

**Extraction quality on transcript content is unmeasured.** Hook events are
single tool operations with a known shape. A transcript turn is a long
free-form message. The extraction prompt was written for the former. The first
bounded run is as much a test of the prompt as of the bridge.

**Cost is unbounded by default.** 22,555 messages at corpus scale is real money,
and the current accounting under-reports: the one extraction attempted so far
fell back to a text-length estimate rather than provider data. Bounding and dry
runs are acceptance criteria for this reason.

**Private content reaches a cloud provider.** Until R3 lands, promotion has no
sensitivity routing, so the bridge must refuse to run against a project unless
the user names it explicitly. No wildcards, no all-projects flag, until routing
exists.
