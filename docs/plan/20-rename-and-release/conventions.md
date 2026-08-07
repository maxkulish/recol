# R0 conventions

The rulebook for the rename-and-release round. Two audiences read it: whoever
implements an R0 task, and whoever reviews one. Reviewers cite a rule by its
id; a finding that no rule covers and that has now appeared twice becomes a new
rule here rather than a second fix in the code.

Rules are added when something goes wrong, not in advance. Every one below
names the run that produced it.

---

## G - The gate

### G1 - The gate is four layers, and only L4 may be absent

`scripts/gate.sh` runs the deterministic layers. `implement.md` Step 5 runs L1
and L4 around it.

| Layer | What | May be absent? |
|---|---|---|
| L1 | The task file's acceptance criteria | no |
| L2 | `cargo fmt` / `check` / `test` | no |
| L3 | `yaml.safe_load` over the YAML we author | no |
| L4 | Model review (lok, or native `Agent` fan-out) | yes |

A run with no L4 is graded by L1-L3. A run where L2 or L3 could not execute is
`INCOMPLETE`, which is not a pass and never becomes one by waiting.

**Why:** R0-01 finished with `outcome: ungraded` and every local check green,
because the only grader the phase file would accept was `.lok/workflows/`, which
this repository does not have. An absent optional reviewer had been wired to
mean an absent gate.

### G2 - `UNAVAILABLE` never reads as `PASS`

`scripts/gate.sh` exits `2`, not `0`, when a layer cannot run - no cargo, no
pyyaml, no task file to read criteria from. Fix the environment; do not
interpret the silence.

### G3 - Re-run the whole gate after a fix, not the failing layer

A fix aimed at one acceptance criterion routinely breaks a test. The outcome
loop's re-run is full for that reason.

### G4 - The gate is negatively validated, per layer

See the record below. Adding a binding layer means adding its seeded failure to
that table in the same change. A layer nobody has watched fail is decoration.

### G5 - Two tiers, because the full gate costs eleven minutes

`cargo test --workspace` runs for about eleven minutes on this tree, most of it
in integration tests that spawn `remem worker --once`. Running it after every
task would cost more than it catches.

- `--quick` per task: fmt, check, YAML. Roughly one minute.
- Full tier once at the phase boundary, and always before a PR.

The runner reports the deferred layer as `DEFERRED`, never as `PASS`, and the
verdict line says the test run is still owed. A quick pass is not a pass.

### G6 - What the gate does not cover yet

CI also runs `cargo clippy --all-targets -- -D warnings`, the plugin version
sync check, the Node runtime tests, and the eval gates. None of them are in
`scripts/gate.sh`, so a green gate can still meet a red CI. R0-05 rebuilds CI
rust-first; align the two then, and record the alignment here.

Naming the gap is the point. A referee that quietly covers less than it appears
to is the same defect as no referee.

---

## Negative validation record

Production Discipline §B.6 step 3: a judge that does not catch breakage is not
a judge. Each row seeds one deliberate defect, runs the gate, and checks that
the gate fails *and names the right layer*. Every seed was reverted immediately;
`git status --porcelain src/` was empty after each run.

Validated on `chore/gate-contract`, 2026-08-07, after confirming the unseeded
full tier passes.

| Layer | Seeded defect | Expected | Observed |
|---|---|---|---|
| L1 | `--task R9-99`, no such task file | exit 2, INCOMPLETE | exit 2, `L1 acceptance UNAVAILABLE no docs/tasks/r9-99-*.md` |
| L2 fmt | Misformatted fn appended to `src/atomic_file.rs` | exit 1, fmt FAIL only | exit 1, `L2 fmt FAIL exit 1`, `L2 check PASS` |
| L2 check | `fn ... -> u8 { "not a u8" }` | exit 1, check FAIL only | exit 1, `L2 check FAIL exit 101`, `L2 fmt PASS` |
| L2 test | `assert_eq!(1, 2)` in a new test module | exit 1, test FAIL only | exit 1, `L2 test FAIL exit 101`, `L2 fmt PASS`, `L2 check PASS` |
| L3 | `docs/status/zz-negative-validation.yaml` with an unclosed flow sequence | exit 1, yaml-status FAIL | exit 1, `L3 yaml-status FAIL unparseable file(s)`, `ParserError: while parsing a flow sequence` |

Two of these matter more than the others. The L3 row is the R0-01 incident
reproduced on purpose: a workflow state file that did not parse while every
local check was green. The L1 row proves the `INCOMPLETE` path, which is the
distinction between "the gate says no" and "there was no gate".

Not validated: the `pyyaml missing` branch, which reports `UNAVAILABLE` on
import failure. Simulating it means breaking the interpreter, so it is read code
rather than exercised code. Treat that one line with the suspicion it deserves.
