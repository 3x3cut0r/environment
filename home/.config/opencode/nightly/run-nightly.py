#!/usr/bin/env python3
"""Run all configured opencode tasks in parallel.

Reads tasks from tasks.json next to this script, launches one
`opencode run` process per enabled task (each in its own project
directory) and writes one log file per task.

Usage:
    run-nightly.py            # run all enabled tasks
    run-nightly.py --dry-run  # print resolved commands, do not execute
"""
from __future__ import annotations

import datetime
import json
import os
import pathlib
import shutil
import subprocess
import sys

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
CONFIG = SCRIPT_DIR / "tasks.json"
LOG_DIR = pathlib.Path.home() / ".local/share/opencode-nightly/logs"
FALLBACK_OPENCODE = "/snap/bin/opencode"


def resolve_opencode() -> str:
    """Prefer $OPENCODE_BIN, then PATH lookup, then the snap fallback."""
    env_bin = os.environ.get("OPENCODE_BIN")
    if env_bin and pathlib.Path(env_bin).exists():
        return env_bin
    found = shutil.which("opencode")
    if found:
        return found
    return FALLBACK_OPENCODE


def load_prompt(task: dict) -> str:
    """Read the prompt from prompt_file (relative to this script) or inline."""
    if "prompt_file" in task:
        path = pathlib.Path(task["prompt_file"])
        if not path.is_absolute():
            path = SCRIPT_DIR / path
        return path.read_text(encoding="utf-8").strip()
    return task["prompt"]


def build_command(opencode: str, task: dict) -> list[str]:
    cmd = [
        opencode,
        "run",
        "--agent",
        task.get("agent", "plan"),
        "--title",
        f"nightly: {task['name']}",
    ]
    if task.get("auto"):
        cmd.append("--auto")
    if task.get("model"):
        cmd += ["--model", task["model"]]
    cmd.append(load_prompt(task))
    return cmd


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    opencode = resolve_opencode()
    tasks = json.loads(CONFIG.read_text(encoding="utf-8"))["tasks"]

    if dry_run:
        print(f"opencode binary: {opencode}")
        for task in tasks:
            state = "enabled" if task.get("enabled", True) else "disabled"
            print(f"\n# {task['name']} ({state}, cwd={task['dir']})")
            print(" ".join(repr(part) for part in build_command(opencode, task)))
        return 0

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%S")

    env = dict(os.environ)
    bin_dir = str(pathlib.Path(opencode).resolve().parent)
    env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "")

    running = []
    for task in tasks:
        name = task["name"]
        if not task.get("enabled", True):
            print(f"[{stamp}] skip {name} (disabled)", flush=True)
            continue

        cmd = build_command(opencode, task)
        log_path = LOG_DIR / f"{stamp}-{name}.log"
        log = open(log_path, "w", encoding="utf-8")
        print(f"[{stamp}] start {name} -> {log_path}", flush=True)
        proc = subprocess.Popen(
            cmd,
            cwd=task["dir"],
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            env=env,
        )
        running.append((name, proc, log))

    failed = 0
    for name, proc, log in running:
        rc = proc.wait()
        log.close()
        print(f"[{stamp}] {name}: exit {rc}", flush=True)
        if rc != 0:
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
