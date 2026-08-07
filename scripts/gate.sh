#!/usr/bin/env bash
# The deterministic half of the implement gate.
#
# The gate has four layers, cheapest and most certain first:
#
#   L1  the task file's acceptance criteria   agent-run; this script only lists them
#   L2  cargo fmt / check / test              here
#   L3  yaml.safe_load over the YAML we write here
#   L4  model review                          .claude/commands/task/phases/implement.md
#
# L4 is allowed to be unavailable. L2 and L3 are not: a check that could not run
# reports UNAVAILABLE and the script exits 2, so "did not run" can never be read
# as "passed". That confusion is what left R0-01 ungraded.
#
# Usage:
#   scripts/gate.sh [--task R0-02] [--quick]
#
#   --task <id>  print the acceptance criteria still owed by a human or agent
#   --quick      defer `cargo test` to the phase boundary (per-task tier)
#
# Exit codes:
#   0  every layer this script owns passed
#   1  at least one layer failed
#   2  at least one layer could not run

set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 2

task_id=""
quick=0

while [ $# -gt 0 ]; do
  case "$1" in
    --task)   task_id="${2:-}"; shift 2 ;;
    --task=*) task_id="${1#*=}"; shift ;;
    --quick)  quick=1; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "gate: unknown argument: $1" >&2; exit 2 ;;
  esac
done

names=()
verdicts=()
notes=()

record() {
  names+=("$1")
  verdicts+=("$2")
  notes+=("${3:-}")
}

# run <label> <command...>
run() {
  local label="$1"
  shift
  printf '\n--- %s: %s\n' "$label" "$*"
  local status=0
  "$@" || status=$?
  case "$status" in
    0) record "$label" PASS ;;
    *) record "$label" FAIL "exit $status" ;;
  esac
}

# yaml_sweep <label> <glob...>
yaml_sweep() {
  local label="$1"
  shift
  printf '\n--- %s: yaml.safe_load %s\n' "$label" "$*"
  local status=0
  python3 - "$@" <<'PY' || status=$?
import glob
import sys

try:
    import yaml
except ModuleNotFoundError:
    print("pyyaml is not installed; cannot verify YAML", file=sys.stderr)
    sys.exit(3)

seen = 0
bad = 0
for pattern in sys.argv[1:]:
    for path in sorted(glob.glob(pattern)):
        seen += 1
        try:
            with open(path, encoding="utf-8") as fh:
                list(yaml.safe_load_all(fh))
        except Exception as exc:
            bad += 1
            print(f"{path}: {type(exc).__name__}: {exc}", file=sys.stderr)

print(f"parsed {seen - bad}/{seen} file(s)")
sys.exit(1 if bad else 0)
PY
  case "$status" in
    0) record "$label" PASS ;;
    3) record "$label" UNAVAILABLE "pyyaml missing" ;;
    *) record "$label" FAIL "unparseable file(s)" ;;
  esac
}

# L1 - acceptance criteria. This script cannot run them: their expected results
# are stated in prose ("returns nothing", "fails for every path"), which is what
# makes them good criteria and bad shell. Print them so nobody forgets they are
# part of the gate.
if [ -n "$task_id" ]; then
  slug="$(printf '%s' "$task_id" | tr '[:upper:]' '[:lower:]')"
  task_file=""
  for candidate in docs/tasks/"$slug"-*.md; do
    [ -f "$candidate" ] && task_file="$candidate" && break
  done

  if [ -z "$task_file" ]; then
    record "L1 acceptance" UNAVAILABLE "no docs/tasks/$slug-*.md"
    echo "gate: no task file matches docs/tasks/$slug-*.md" >&2
  else
    criteria="$(awk '/^## Acceptance criteria/{f=1;next} /^## /{f=0} f' "$task_file")"
    count="$(printf '%s\n' "$criteria" | grep -c '^- \[' || true)"
    printf '\n--- L1 acceptance: %s\n%s\n' "$task_file" "$criteria"
    if [ "$count" -eq 0 ]; then
      record "L1 acceptance" UNAVAILABLE "no criteria found in $task_file"
    else
      record "L1 acceptance" MANUAL "$count criteria in $task_file"
    fi
  fi
else
  record "L1 acceptance" MANUAL "no --task given; run the task file's criteria"
fi

# L2 - the compiler and the test suite.
run "L2 fmt"   cargo fmt --check
run "L2 check" cargo check --workspace --all-targets

if [ "$quick" -eq 1 ]; then
  record "L2 test" DEFERRED "quick tier; run at phase end"
else
  run "L2 test" cargo test --workspace
fi

# L3 - the YAML we author by hand. Nothing else parses these before they are
# pushed, and a state file that does not load is invisible to every other check.
yaml_sweep "L3 yaml-status"    'docs/status/*.yaml' '.claude/templates/*.yaml'
yaml_sweep "L3 yaml-workflows" '.github/workflows/*.yml' '.github/workflows/*.yaml'

# Summary. The orchestrator copies these lines into gate.layers in the workflow
# state file, so keep the shape stable.
mode="full"
[ "$quick" -eq 1 ] && mode="quick"

printf '\nGATE SUMMARY (%s tier)\n' "$mode"
failed=0
unavailable=0
for i in "${!names[@]}"; do
  printf '  %-18s %-11s %s\n' "${names[$i]}" "${verdicts[$i]}" "${notes[$i]}"
  case "${verdicts[$i]}" in
    FAIL)        failed=1 ;;
    UNAVAILABLE) unavailable=1 ;;
  esac
done

if [ "$failed" -eq 1 ]; then
  echo "  verdict: FAIL"
  exit 1
fi
if [ "$unavailable" -eq 1 ]; then
  echo "  verdict: INCOMPLETE (a layer could not run; this is not a pass)"
  exit 2
fi
if [ "$quick" -eq 1 ]; then
  echo "  verdict: PASS (quick tier; cargo test still owed at the phase boundary)"
else
  echo "  verdict: PASS"
fi
