# docs/designs - Per-issue design documents

Design documents written against a single Linear issue, one file per issue.
`/design-doc:create REC-XX` writes them, `/design-doc:review` runs them past
several models, and `/design-doc:finalize` marks one approved.

## Relationship to `docs/plan/`

These two directories look similar and are not interchangeable.

`docs/plan/` holds fork-owned planning: the product brief, the roadmap, and a
directory per substantial work item with the `product.md` / `tech.md` /
`tasks.md` triad. It is hand-maintained and it is where a work item starts.

This directory holds the output of the Linear-driven command workflow. A file
appears here because an issue exists and someone ran `/design-doc:create` on
it. Nothing here is authored by hand, and nothing here supersedes a document in
`docs/plan/`.

When a roadmap item is large enough to need its own spec triad, it belongs in
`docs/plan/`. When it is a single tracked issue, it belongs here.

## Conventions

- Filename: `rec-<issue-number>-<short-slug>.md`, lowercase.
- Architecture decisions that outlive the issue go to `docs/adr/` under the
  existing `YYYY-MM-DD-<slug>.md` convention, not here.
- Review output for a design lands in `docs/reviews/`, keyed by the same issue
  number. Workflow state lands in `docs/status/`.
