# R0-13 - Retire the old installation

Type: **HITL** | Blocked by: R0-12 | Blocks: none
Phase: 3 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 3)

## Goal

The old binary, data directory, and Keychain entry are gone, and a fresh shell
runs `recol` with no manual steps.

## This is the irreversible task

Everything before it is additive. Do not start until R0-12's acceptance criteria
have all passed, and keep the R0-11 snapshot until well after.

## Context

**The `.zshrc` wrapper is the trap.** It lives outside the repository, and
references both `remem-cipher-key` and the `remem` command. No repository change
can update it. Until it is edited, every invocation fails with "refusing to open
recol database without a SQLCipher key", which reads like an unrelated error
rather than a missing wrapper.

The shell function also **shadows** the binary, so `which remem` reports the
function, not the executable. Remove the function first or the uninstall check
misreports.

The crates.io package is `remem-ai`, not `remem`, so the uninstall command takes
the package name.

Nothing in `~/.claude/settings.json` or `~/.codex/config.toml` references the
old name, verified on 2026-07-27, so no host integration breaks here.

## Scope

**The recursive delete of `~/.remem` may be refused by a local safety hook.**
If that happens, stop and have a human run the deletion or explicitly approve
it. Do not substitute a different command to reach the same end state - the
hook exists for exactly this path.

- [ ] Replace the `.zshrc` wrapper: read `recol-cipher-key`, export
      `RECOL_CIPHER_KEY`, invoke `recol`
- [ ] `cargo uninstall remem-ai`
- [ ] Move `~/.remem` aside, then delete once confirmed
- [ ] Delete the `remem-cipher-key` Keychain entry

## Acceptance criteria

- [ ] In a **new** shell, `recol status` succeeds with no manual `export`
- [ ] `which recol` resolves to the cargo bin path
- [ ] `command -v remem` returns nothing, and `type remem` reports not found
- [ ] `ls ~/.remem` fails
- [ ] `security find-generic-password -s remem-cipher-key` exits non-zero
- [ ] `security find-generic-password -s recol-cipher-key` exits 0
- [ ] The R0-11 snapshot is still present and still restorable
