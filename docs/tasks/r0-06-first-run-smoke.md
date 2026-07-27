# R0-06 - Automate the isolated first-run smoke

Type: **AFK** | Blocked by: R0-05 | Blocks: none
Phase: 1 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 1)

## Goal

CI proves the tool starts cleanly on a machine that has never had it installed,
so the data-path rename in R0-09 cannot silently break new installations.

## Context

Nothing currently verifies first-run behaviour. Every existing test runs against
a developer machine that already has `~/.remem`, so a broken data path would
only surface on someone else's computer - or on yours, after R0-13 deletes the
old directory.

**Reuse the documented procedure.** `.agents/skills/remem-first-run-smoke/SKILL.md`
already specifies it: always use a temporary `HOME` and `REMEM_DATA_DIR`, prefer
`--dry-run` before any activation command that edits host config, never run hook
activation against the real home, and keep stdout and stderr when it fails.
This task automates that skill rather than inventing a procedure.

The script must fail closed if `HOME` was not overridden. A smoke that silently
runs against the real home would corrupt the developer's state, which is exactly
what the skill warns about.

## Scope

- [ ] `scripts/ci/smoke_first_run.sh` creating a temporary `HOME` and data dir
- [ ] Refuses to run if `HOME` resolves to the real home directory
- [ ] Exercises init, `status`, and `doctor` against the isolated directory
- [ ] Cleans up the temporary directories on success and preserves them on
      failure, with logs
- [ ] Wired into the `rust` job in `ci.yml`

## Acceptance criteria

- [ ] `scripts/ci/smoke_first_run.sh` exits 0 on a clean checkout
- [ ] Running it leaves the real `~/.remem` byte-identical: capture `find ~/.remem -type f -exec shasum {} +` before and after and diff them
- [ ] Running it does not create or modify `~/.claude/settings.json` or `~/.codex/config.toml`
- [ ] With `HOME` left at its real value the script exits non-zero with an explicit refusal, and does not create any directory
- [ ] The step appears in the `rust` job and passes on a pull request
