# R0-07 - Add hosted ARM and Intel macOS jobs

Type: **AFK** | Blocked by: R0-00, R0-05 | Blocks: R0-09
Phase: 1 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 1)

## Goal

macOS is covered on both architectures by GitHub-hosted runners, so R6's
Keychain work and the darwin release builds have a gate, without attaching a
personal machine to a public repository.

## Context

CI has no macOS coverage at all today, despite macOS being the primary target.

**Use hosted runners, register none.** GitHub's hosted images cover both
architectures: `macos-latest`, `macos-14`, `macos-15`, and `macos-26` are ARM64,
and the `-intel` suffixed labels (`macos-15-intel`, `macos-26-intel`) are
x86_64. `gh api repos/maxkulish/recol/actions/runners` returns `total_count: 0`
and must stay that way. This repository is public, so a self-hosted runner would
put the machine - including the Keychain holding the database key - within reach
of any pull request. Hosted ARM removes the need rather than mitigating it.

**`--no-default-features` stays on `x86_64-apple-darwin` even on a native Intel
host.** The ort constraint is on the target, not the builder: ONNX Runtime ships
no prebuilt binary for that target, so embedding falls back to the feature-hash
provider and the degradation stays visible in `status` and `doctor`. Running on
`macos-15-intel` gives a native host, not a prebuilt library.

## Scope

- [ ] Job `macos-arm` on `macos-15`: `cargo build` and `cargo test --locked`
- [ ] Job `macos-intel` on `macos-15-intel`: same, with
      `--no-default-features`
- [ ] No `runs-on: [self-hosted, ...]` anywhere

## Acceptance criteria

- [ ] Both jobs run and pass on a pull request
- [ ] `rg -n "self-hosted" .github/workflows/` returns nothing
- [ ] `gh api repos/maxkulish/recol/actions/runners --jq .total_count` returns 0
- [ ] `rg -n "no-default-features" .github/workflows/ci.yml` matches only the `macos-intel` job
- [ ] The `macos-intel` job log shows the feature-hash embedding fallback rather than a link failure
