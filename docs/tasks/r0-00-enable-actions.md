# R0-00 - Get GitHub Actions actually running

Type: **HITL** | Blocked by: none | Blocks: R0-02, R0-04, R0-05, R0-06, R0-07
Phase: 0 | Added 2026-08-03 after R0-01 found that Actions has never run

## Goal

A pull request and a push to `main` each produce a workflow run that reaches a
conclusion, so the six acceptance criteria across five tasks that read "on a
pull request, X runs and passes" can be satisfied instead of waived.

## Why this exists

R0-01 merged as PR #1 with CI never running. Not failing - never starting.

Verified on 2026-08-03:

```
gh api repos/maxkulish/recol/actions/runs --jq .total_count   -> 0
```

Zero for every one of the six workflows individually as well. The obvious
explanations are all ruled out:

- `actions/permissions` reports `enabled: true`, `allowed_actions: all`
- all six workflows are registered with state `active`
- all six parse as valid YAML (`python3 -c "import yaml; yaml.safe_load(...)"`)
- `ci.yml` triggers on `push: branches: [main]` and `pull_request`, and both
  have happened, including PR #1 merged 2026-08-03 and several direct pushes

Leading hypothesis: the repository was **created as a fork** on 2026-07-26 and
detached later. GitHub suppresses workflow runs on forks until a human enables
them from the Actions tab, detaching does not clear that state, and the
permissions API does not expose the gate. Confirm before assuming.

## Do the disables first

Enabling Actions with the current workflow set is not safe. Four workflows fire
immediately, and one of them tries to ship:

| Workflow | Trigger | What happens |
|---|---|---|
| `auto-release.yml` | `workflow_run` on CI completing on `main` | **attempts to tag and publish a release**; its preflight requires three absent secrets, so it fails, but it should never be given the chance |
| `closure-audit.yml` | `pull_request_target` | needs `issues: write`; issues are disabled on this repo (`has_issues: false`), so it errors |
| `sensitive-governance.yml` | `pull_request_target` | runs upstream's classifier on every PR; on a public repo this is also attack surface |
| `pages.yml` | push to `main` | deploys a Pages site that is not configured |

Disable those four **before** enabling runs. They can be disabled now, while
Actions is dormant, so no triggering event ever reaches them. R0-02 deletes
three of them for good; this is the interim guard.

Leave `release.yml` enabled: it fires only on `v*` tags and `workflow_dispatch`,
and no tag is pushed before R0-17.

Workflow IDs as of 2026-08-03: auto-release `320977665`, ci `320977666`,
closure-audit `320977668`, pages `320977669`, release `320977670`,
sensitive-governance `320977672`.

## Expect the first CI run to fail

`ci.yml` still contains the inherited governance gates, including the step that
replays hardcoded GH813 and PR 906 commit SHAs, which a detached repository
cannot satisfy. A red first run **satisfies this task**. The criterion is that a
run happens and concludes, not that it passes. R0-02 and R0-05 make it green.

A run stuck in `queued` is not a conclusion and does not count.

## The gh trap

`gh run list` without `--repo` resolves through the worktree's remotes and
returns `majiayu000/remem`'s green history, which reads as though CI is healthy
here. R0-01 lost time to this. Always pass `--repo maxkulish/recol`.

## Scope

- [ ] Disable `auto-release`, `closure-audit`, `sensitive-governance`, `pages`
- [ ] Determine the actual cause of the suppression and record it
- [ ] Enable workflow runs
- [ ] Prove a run on a pull request and a run on a push to `main`

## Acceptance criteria

- [ ] `gh workflow list --repo maxkulish/recol` shows `auto-release`,
      `closure-audit`, `sensitive-governance`, and `pages` as `disabled_manually`,
      and `CI` as `active`
- [ ] `gh api repos/maxkulish/recol/actions/runs --jq .total_count` returns 1 or more
- [ ] `gh run list --repo maxkulish/recol --workflow ci.yml --event pull_request` returns at least one row
- [ ] `gh run list --repo maxkulish/recol --workflow ci.yml --event push` returns at least one row
- [ ] Every run above has a `conclusion` that is not null and not `cancelled` -
      `gh run list --repo maxkulish/recol --json conclusion --jq '.[].conclusion'`
- [ ] `gh run list --repo maxkulish/recol --workflow auto-release.yml` returns no rows
- [ ] The cause of the suppression is written into this file before it is closed,
      replacing the hypothesis above
