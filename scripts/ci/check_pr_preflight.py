#!/usr/bin/env python3
"""Run PR CI gates locally without short-circuiting on the first failure."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


@dataclass
class StepResult:
    name: str
    status: str
    detail: str = ""


def run(
    name: str,
    command: list[str],
    *,
    env: dict[str, str] | None = None,
) -> StepResult:
    print(f"\n==> {name}", flush=True)
    print("+ " + " ".join(command), flush=True)
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    result = subprocess.run(command, cwd=ROOT, env=merged_env, check=False)
    if result.returncode == 0:
        return StepResult(name, "PASS")
    return StepResult(name, "FAIL", f"exit {result.returncode}")


def run_expected_failure(
    name: str,
    command: list[str],
    expected_text: str,
    log_path: Path,
) -> StepResult:
    print(f"\n==> {name}", flush=True)
    print("+ " + " ".join(command), flush=True)
    with log_path.open("w", encoding="utf-8") as handle:
        result = subprocess.run(
            command,
            cwd=ROOT,
            stdout=handle,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
    text = log_path.read_text(encoding="utf-8", errors="replace")
    print(text)
    if result.returncode == 0:
        return StepResult(name, "FAIL", "expected non-zero exit")
    if expected_text not in text:
        return StepResult(name, "FAIL", f"missing expected output: {expected_text}")
    return StepResult(name, "PASS")


def fast_steps(base: str, head: str) -> list[tuple[str, list[str]]]:
    return [
        ("Check plugin version sync", ["python3", "scripts/ci/check_plugin_version_sync.py"]),
        ("Check public surface", ["python3", "scripts/ci/check_public_surface.py"]),
        ("Check public benchmark claims", ["python3", "scripts/ci/check_public_claims.py"]),
        ("Check source file size guard", ["python3", "scripts/ci/check_file_size.py"]),
        ("Check release workflows", ["python3", "scripts/ci/check_release_workflows.py"]),
        (
            "Test plugin runtime scripts",
            [
                "node",
                "--test",
                "plugins/remem/scripts/remem-runtime.test.js",
                "plugins/remem/apps/remem/request-security.test.js",
                "plugins/remem/apps/remem/server.test.js",
                "npm/remem/scripts/install.test.js",
            ],
        ),
        ("Check version bump", ["python3", "scripts/ci/check_version_bump.py", base, head]),
        ("Run cargo fmt --check", ["cargo", "fmt", "--check"]),
        (
            "Run cargo clippy --all-targets -- -D warnings",
            ["cargo", "clippy", "--all-targets", "--", "-D", "warnings"],
        ),
    ]


def full_steps() -> list[tuple[str, list[str]]]:
    return [
        ("Run native web API smoke", ["scripts/smoke_native_web_api.sh"]),
        (
            "Run extraction baseline gate",
            ["cargo", "run", "--", "eval-extraction", "--json", "--check-baseline"],
        ),
        (
            "Run eval regression gates",
            ["cargo", "run", "--", "eval-gates", "--json-out", "/tmp/remem-eval-gates.json"],
        ),
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run the pull_request CI gates locally and report every failing gate "
            "instead of stopping at the first failure."
        )
    )
    parser.add_argument("--base", default="origin/main", help="Base ref for PR diff checks")
    parser.add_argument("--head", default="HEAD", help="Head ref for PR diff checks")
    parser.add_argument(
        "--pr-body-file",
        help="Accepted for compatibility; no longer used",
    )
    parser.add_argument(
        "--pr-title",
        help="Accepted for compatibility; no longer used",
    )
    parser.add_argument(
        "--skip-pr-body-checks",
        action="store_true",
        help="Accepted for compatibility; no longer used",
    )
    parser.add_argument(
        "--fast",
        action="store_true",
        help="Run fast/mechanical gates only; omit smoke, eval, and cargo test",
    )
    return parser.parse_args()


def print_summary(results: list[StepResult]) -> int:
    print("\n== Summary")
    failed = 0
    for item in results:
        suffix = f" - {item.detail}" if item.detail else ""
        print(f"{item.status:4} {item.name}{suffix}")
        if item.status == "FAIL":
            failed += 1
    if failed:
        print(f"\npreflight failed: {failed} gate(s) failed")
        return 1
    print("\npreflight passed")
    return 0


def main() -> int:
    args = parse_args()
    results: list[StepResult] = []

    for name, command in fast_steps(args.base, args.head):
        results.append(run(name, command))

    if not args.fast:
        for name, command in full_steps():
            results.append(run(name, command))
        with tempfile.TemporaryDirectory(prefix="remem-preflight-") as raw_tmp:
            tmp = Path(raw_tmp)
            results.append(
                run_expected_failure(
                    "Prove eval gate blocks constructed regression",
                    [
                        "cargo",
                        "run",
                        "--",
                        "eval-gates",
                        "--simulate-golden-regression",
                        "--json-out",
                        str(tmp / "eval-gates-regression.json"),
                    ],
                    "golden.slice.temporal.hit_at_k regressed",
                    tmp / "eval-gates-regression.log",
                )
            )
            results.append(
                run_expected_failure(
                    "Prove capacity gate blocks constructed regression",
                    [
                        "cargo",
                        "run",
                        "--",
                        "eval-gates",
                        "--simulate-capacity-regression",
                        "--json-out",
                        str(tmp / "eval-gates-capacity-regression.json"),
                    ],
                    "capacity.degradation.fused.recall_at_k_loss increased",
                    tmp / "eval-gates-capacity-regression.log",
                )
            )
        results.append(run("Run cargo test", ["cargo", "test"]))

    return print_summary(results)


if __name__ == "__main__":
    sys.exit(main())
