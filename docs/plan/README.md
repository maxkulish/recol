# docs/plan - Recol planning

Planning documents for this project. It began as a fork of `majiayu000/remem`
and was detached on 2026-07-27, so `maxkulish/recol` is now a standalone
repository with no GitHub parent. The `upstream` remote remains configured and
still fetches.

## Why this directory, and not `specs/`

Upstream numbers its specs by its own GitHub issues (`specs/GH759/` and so on).
This fork keeps its planning separate so it stays visibly fork-owned and does
not interleave with inherited specs.

Two inherited rules were removed, both of which protected a directory that does
not exist in this repository: a bare `plan/` in `.gitignore` matching at any
depth, and a matching `"plan/"` entry in the `Cargo.toml` `exclude` list.
Upstream uses a root `plan/` as untracked scratch; this fork does not, and
planning here is tracked.

`Cargo.toml` still excludes `docs/` from the published crate, which is
deliberate. These documents belong in the repository and in review, not in a
crate tarball. If planning ever needs to ship, that exclude is the line to
revisit.

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

Detachment settled that question in one direction. The `upstream` remote stays
configured because cherry-picking a specific upstream fix still works and costs
nothing to keep available. Contributing back does not: a detached repository
cannot open a pull request against its former parent, so offering a change
would mean forking `majiayu000/remem` afresh and replaying the commit there.

Items in `01-roadmap.md` still carry a classification, but read it as "would
this stand alone if offered", not as a route that currently exists. Three items
are genuinely self-contained and would apply to any installation: the key
source (R6) and the two retrieval fixes (R5a, R5b). If contributing anything,
contribute those.

## Index

- `00-product-brief.md` - why this fork exists, what it changes, how success is
  measured. Read first.
- `01-roadmap.md` - ordered work items, dependencies, upstream classification.
- `10-transcript-bridge/` - the central fork feature: promote archived
  transcripts into the curation pipeline.
- `20-rename-and-release/` - R0: rename to recol, rebuild CI, and narrow
  distribution to GitHub Releases and a Homebrew tap. Sequenced first.
- `30-command-suite-adaptation.md` - adapt `.claude/commands/` to the 2026-08
  migration guidance: rebuild the referee, make the R0 file-based track
  first-class, rightsize the suite. Tooling, not product; single file until
  work starts.

## Source material

The design work behind this fork lives outside the repository, in the
investigations notes at `~/Work/investigations/recol/`. The most load-bearing
documents are the design brief (decisions D1-D12) and the remem evaluation that
produced the finding this fork exists to fix. Reference them; do not copy them
here, because they will keep changing.
