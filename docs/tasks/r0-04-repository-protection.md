# R0-04 - Configure branch protection, tag ruleset, release environment

Type: **HITL** | Blocked by: R0-05 | Blocks: R0-14
Phase: 0 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 0)

## Goal

The repository enforces what every other task assumes: `main` is protected,
published tags are immutable, and releases require a human approval.

## Context

None of this exists today. Verified on 2026-07-27:

```
gh api repos/maxkulish/recol/rulesets              -> []
gh api repos/maxkulish/recol/branches/main/protection -> 404 Branch not protected
gh api repos/maxkulish/recol/environments          -> total_count 0
```

So "merged behind green CI" is currently aspiration, and deleting
`auto-release.yml` in R0-14 removes the only checks tying a tag to a verified
commit - its exact-main-SHA verification and immutable-tag handling. Those
guarantees move here and into R0-14's preflight.

**Blocked by R0-05, not the reverse.** Branch protection pins a required status
check *by name*, and R0-05 restructures `ci.yml` into a job named `rust`.
Configuring protection first would pin a check that stops existing.

This is HITL: it changes repository settings, not code, and needs your account.

## Scope

- [ ] Branch protection on `main`: require the `rust` status check, require
      linear history
- [ ] Ruleset over `refs/tags/v*`: restrict creation, block update, block delete
- [ ] A `release` environment with required reviewers

## Acceptance criteria

- [ ] `gh api repos/maxkulish/recol/branches/main/protection --jq .required_status_checks.contexts` includes `rust`
- [ ] `gh api repos/maxkulish/recol/rulesets --jq 'length'` returns at least 1
- [ ] `gh api repos/maxkulish/recol/rulesets --jq '.[].target'` includes `tag`
- [ ] `gh api repos/maxkulish/recol/environments --jq .total_count` returns 1
- [ ] A direct `git push origin main` from a clean clone is refused
- [ ] Creating tag `v0.0.0-protection-test` then `git push --delete origin v0.0.0-protection-test` is refused; delete the local tag afterwards
