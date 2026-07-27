# R0-16 - Plugin runtime download smoke

Type: **AFK** | Blocked by: R0-10 | Blocks: R0-17
Phase: 4 | Spec: `docs/plan/20-rename-and-release/tech.md` (Phase 4)

## Goal

A test that fails when the plugin cannot fetch its runtime, so the resolver
breaks in CI rather than on a user's machine.

## Context

The plugin resolver is the least-tested path in the project, and it only matters
after a real release - precisely when it is hardest to fix.

**The checked-in manifest blocks remote resolution.**
`plugins/recol/runtimes/recol-releases.json` is `state: "unreleased"`, and
`plugins/recol/scripts/recol-runtime.js:359` reads:

```js
if (localRelease?.state === "unreleased") return null;
```

That returns `null` **before** the base-URL check on the next line, so uploading
`recol-releases.json` to the GitHub Release does not activate fallback. The
manifest must be updated in the repository after publishing, which R0-18 does.
This smoke is what proves that transition worked.

The existing Node tests (`recol-runtime.test.js`) cover unit behaviour. This is
different: an integration smoke with **no repository binary and nothing matching
on `PATH`**, so the only way it can succeed is a real download.

## Scope

- [ ] A smoke that clears `PATH` of any `recol`, points at a release base URL,
      and asserts the runtime downloads, verifies its checksum, installs, and
      starts
- [ ] Fails closed when no asset resolves, rather than silently falling back to
      a local binary
- [ ] Parameterised by base URL so it can run against a release candidate before
      production

## Acceptance criteria

- [ ] With `state: "unreleased"` in the manifest, the smoke exits non-zero and
      its message names the unreleased state as the cause
- [ ] With a repository binary present, the smoke still refuses to pass on it -
      it must prove a download, not a fallback
- [ ] A checksum mismatch fails the smoke rather than installing the asset
- [ ] Against the R0-17 release candidate's base URL, the smoke exits 0 and the
      downloaded runtime reports `recol 0.7.0`
