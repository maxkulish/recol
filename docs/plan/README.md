# docs/plan - Recol fork planning

Planning documents for this fork. Upstream is `majiayu000/remem`; this is
`maxkulish/recol`.

## Why this directory, and not `specs/`

Upstream numbers its specs by its own GitHub issues (`specs/GH759/` and so on).
This fork keeps its planning separate so it stays visibly fork-owned and does
not interleave with inherited specs.

One inherited `.gitignore` rule had to change: upstream carried a bare `plan/`
matching at any depth, because it uses a root `plan/` as untracked scratch and
`Cargo.toml` excludes it from the published crate. That rule is now anchored to
`/plan/`, so the root scratch directory stays ignored and this one is tracked.

## Conventions

Each substantial work item gets a directory with the same triad upstream uses,
so a maintainer reading a PR sees a familiar shape:

- `product.md` - the problem, who has it, and what "done" means
- `tech.md` - current code paths, the design, tests, migration, risks
- `tasks.md` - ordered work with parallel splits and verification

Small items live as entries in `01-roadmap.md` until they are next; they get a
directory when work starts. No placeholder directories.

Architecture decisions go in `docs/adr/` following the existing
`YYYY-MM-DD-<slug>.md` convention with Status / Decision / Drivers / Evidence /
Consequences / Follow-ups. Use an ADR when the decision outlives the work item.

## Relationship to upstream

The working assumption is **divergence**: the planned changes go deep enough
into extraction, routing, and the backend layer that merging upstream wholesale
stops being realistic. Development happens on `main` without staging changes for
contribution.

The `upstream` remote stays configured anyway, because it costs nothing and
keeps two options open: cherry-picking a specific upstream fix, and offering a
self-contained change back if one turns out to be cleanly separable. Items in
`01-roadmap.md` still carry a classification for that reason - read it as "would
this stand alone if offered", not as a commitment to offer it.

Three items are genuinely self-contained and would apply to any installation:
the key source (R6) and the two retrieval fixes (R5a, R5b). If contributing
anything, contribute those.

## Index

- `00-product-brief.md` - why this fork exists, what it changes, how success is
  measured. Read first.
- `01-roadmap.md` - ordered work items, dependencies, upstream classification.
- `10-transcript-bridge/` - the central fork feature: promote archived
  transcripts into the curation pipeline.

## Source material

The design work behind this fork lives outside the repository, in the
investigations notes at `~/Work/investigations/recol/`. The most load-bearing
documents are the design brief (decisions D1-D12) and the remem evaluation that
produced the finding this fork exists to fix. Reference them; do not copy them
here, because they will keep changing.
