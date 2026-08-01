# docs/reviews - Multi-model review output

Raw review output, one file per issue per reviewer. `/design-doc:review`
produces these for a design document and `/pr:review` for a pull request.

Reviews are run across several models and personas rather than one, because the
failure mode being guarded against is a single reviewer being confidently wrong
in a way nobody checks. Each reviewer writes its own file; a synthesis file
then reconciles them and is the one worth reading first.

## Conventions

Filenames key on the issue number and the reviewer:

- `rec-<n>-review-<model>.md` for model reviews (`gemini`, `ollama`,
  `claude-fallback`)
- `rec-<n>-review-<persona>.md` for persona reviews, whose prompts live in
  `.claude/templates/review-personas/` (`security`, `concurrency`,
  `backend-integration`)
- `rec-<n>-review-synthesis.md` reconciles the above, using
  `.claude/templates/review-synthesis.md`
- `rec-<n>-<model>-validation.md` and `rec-<n>-validation-synthesis.md` for the
  validation pass

## What belongs here

Reviewer output, kept as evidence of what was checked and by whom. A finding
that survives review and changes the design belongs in the design document
itself, in `docs/designs/`, not only in the review that produced it. Treat
these files as the audit trail, not as the current state of anything.
