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

# Nothing below needs bash 4. That is deliberate: macOS ships 3.2 and hosted
# macOS runners resolve `env bash` to it, so a bash-4 construct anywhere here
# would make the gate unrunnable on exactly the CI that R0-07 adds.
if ! command -v git >/dev/null 2>&1; then
  echo "gate: git is not installed; cannot locate the repository root" >&2
  exit 2
fi

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
#
# A missing tool is not a failing check. `cargo` absent means this layer could
# not run, which is UNAVAILABLE and exit 2; mapping it to FAIL would report an
# environment problem as a code problem, and the whole point of the exit-2 state
# is that those two are not the same answer.
run() {
  local label="$1"
  shift
  local exe="$1"

  if ! command -v "$exe" >/dev/null 2>&1; then
    printf '\n--- %s: %s\n%s: not installed\n' "$label" "$*" "$exe" >&2
    record "$label" UNAVAILABLE "$exe not installed"
    return
  fi

  printf '\n--- %s: %s\n' "$label" "$*"
  local status=0
  "$@" || status=$?
  case "$status" in
    0)       record "$label" PASS ;;
    126|127) record "$label" UNAVAILABLE "$exe could not be executed (exit $status)" ;;
    *)       record "$label" FAIL "exit $status" ;;
  esac
}

# yaml_sweep <label> <glob...>
yaml_sweep() {
  local label="$1"
  shift
  printf '\n--- %s: yaml.safe_load %s\n' "$label" "$*"

  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is not installed; cannot verify YAML" >&2
    record "$label" UNAVAILABLE "python3 not installed"
    return
  fi

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
    0)       record "$label" PASS ;;
    3)       record "$label" UNAVAILABLE "pyyaml missing" ;;
    126|127) record "$label" UNAVAILABLE "python3 could not be executed (exit $status)" ;;
    *)       record "$label" FAIL "unparseable file(s)" ;;
  esac
}

# L1 - acceptance criteria. This script cannot run them: their expected results
# are stated in prose ("returns nothing", "fails for every path"), which is what
# makes them good criteria and bad shell. Print them so nobody forgets they are
# part of the gate.
#
# The reading and counting is pure bash rather than awk and grep. This is the
# layer that reports what is missing, so it must not go quiet when something is
# missing: an absent `grep` used to leave the count blank while the layer still
# claimed MANUAL.
if [ -n "$task_id" ]; then
  slug=""
  if command -v tr >/dev/null 2>&1; then
    slug="$(printf '%s' "$task_id" | tr 'A-Z' 'a-z')"
  elif [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
    slug="${task_id,,}"
  else
    record "L1 acceptance" UNAVAILABLE "cannot lowercase the task id: no tr, bash < 4"
    echo "gate: neither tr nor bash 4 available to normalise '$task_id'" >&2
  fi

  task_file=""
  for candidate in ${slug:+docs/tasks/"$slug"-*.md}; do
    [ -f "$candidate" ] && task_file="$candidate" && break
  done

  if [ -z "$slug" ]; then
    : # already recorded UNAVAILABLE above
  elif [ -z "$task_file" ]; then
    record "L1 acceptance" UNAVAILABLE "no docs/tasks/$slug-*.md"
    echo "gate: no task file matches docs/tasks/$slug-*.md" >&2
  else
    criteria=""
    count=0
    in_section=0
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        '## Acceptance criteria'*) in_section=1; continue ;;
        '## '*)                    in_section=0 ;;
      esac
      if [ "$in_section" -eq 1 ]; then
        criteria+="$line"$'\n'
        case "$line" in
          '- ['*) count=$((count + 1)) ;;
        esac
      fi
    done < "$task_file"
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
