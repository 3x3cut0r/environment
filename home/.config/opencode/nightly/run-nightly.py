#!/usr/bin/env python3
"""Run all configured opencode tasks in parallel.

Reads tasks from tasks.json next to this script, launches one
`opencode run` process per enabled task (each in its own project
directory) and writes one log file per task.

When tmux is available, each task runs in a named window of the most
recently used tmux session (attached sessions win, then the latest
session activity). If no tmux server is running, a dedicated detached
"opencode-nightly" session is created. Windows keep their names
(automatic-rename is disabled per window), stay open after the task
finishes (remain-on-exit) and are renamed to "nightly-<task>-done" or
"nightly-<task>-fail". Without tmux, tasks run headless as before.

Usage:
    run-nightly.py            # run all enabled tasks
    run-nightly.py --dry-run  # print resolved commands, do not execute
"""
from __future__ import annotations

import datetime
import json
import os
import pathlib
import shlex
import shutil
import subprocess
import sys
import time

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
CONFIG = SCRIPT_DIR / "tasks.json"
LOG_DIR = pathlib.Path.home() / ".local/share/opencode-nightly/logs"
FALLBACK_OPENCODE = "/snap/bin/opencode"
TMUX_SESSION = "opencode-nightly"
WINDOW_PREFIX = "nightly"
POLL_SECONDS = 5


def resolve_opencode() -> str:
    """Prefer $OPENCODE_BIN, then PATH lookup, then the snap fallback."""
    env_bin = os.environ.get("OPENCODE_BIN")
    if env_bin and pathlib.Path(env_bin).exists():
        return env_bin
    found = shutil.which("opencode")
    if found:
        return found
    return FALLBACK_OPENCODE


def resolve_tmux() -> str | None:
    """Return the tmux binary path, or None when tmux is unavailable."""
    return shutil.which("tmux")


def resolve_target_session(tmux: str) -> tuple[str, bool]:
    """Pick where nightly windows should go.

    Prefers the most recently used session: attached sessions win,
    then the latest session activity. Returns (session_name,
    needs_new_session); needs_new_session is True when no tmux server
    is running and TMUX_SESSION has to be created instead.
    """
    result = subprocess.run(
        [
            tmux,
            "list-sessions",
            "-F",
            "#{session_attached} #{session_activity} #{session_name}",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return TMUX_SESSION, True
    best_key: tuple[int, int] | None = None
    best_name = ""
    for line in result.stdout.splitlines():
        parts = line.split(" ", 2)
        if len(parts) != 3:
            continue
        try:
            key = (int(parts[0]), int(parts[1]))
        except ValueError:
            continue
        if best_key is None or key > best_key:
            best_key, best_name = key, parts[2]
    if best_key is None:
        return TMUX_SESSION, True
    return best_name, False


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


def build_window_command(tmux: str, cmd: list[str], log_path: pathlib.Path) -> str:
    """Wrap a task command for a tmux window.

    Keeps the log file via tee, preserves the task exit code via
    pipefail, and enables remain-on-exit from inside the pane so the
    window survives even when the command exits immediately.
    """
    bin_dir = shlex.quote(str(pathlib.Path(cmd[0]).resolve().parent))
    inner = (
        f"export PATH={bin_dir}:$PATH; "
        "set -o pipefail; "
        f"{shlex.quote(tmux)} set-option -w -t \"$TMUX_PANE\" remain-on-exit on 2>/dev/null; "
        f"{shlex.join(cmd)} 2>&1 | tee -a {shlex.quote(str(log_path))}"
    )
    return f"bash -c {shlex.quote(inner)}"


def create_window(
    tmux: str,
    session: str,
    needs_new_session: bool,
    name: str,
    task: dict,
    window_cmd: str,
) -> str | None:
    """Create a named tmux window for a task and return its window id."""
    window_name = f"{WINDOW_PREFIX}-{name}"
    if needs_new_session:
        create = [
            tmux,
            "new-session",
            "-d",
            "-s",
            session,
            "-n",
            window_name,
            "-c",
            task["dir"],
            "-P",
            "-F",
            "#{window_id}",
            window_cmd,
        ]
    else:
        create = [
            tmux,
            "new-window",
            "-d",
            "-t",
            session,
            "-n",
            window_name,
            "-c",
            task["dir"],
            "-P",
            "-F",
            "#{window_id}",
            window_cmd,
        ]
    result = subprocess.run(create, capture_output=True, text=True)
    window_id = result.stdout.strip()
    if result.returncode != 0 or not window_id:
        return None
    # Pin the window name (tmux.conf enables automatic-rename globally)
    # and keep the pane after exit; the pane command enables
    # remain-on-exit itself to cover instantly failing commands.
    for option, value in (
        ("automatic-rename", "off"),
        ("allow-rename", "off"),
        ("remain-on-exit", "on"),
    ):
        subprocess.run(
            [tmux, "set-option", "-w", "-t", window_id, option, value],
            capture_output=True,
        )
    return window_id


def wait_for_window(tmux: str, window_id: str) -> int | None:
    """Wait for the pane in a window to finish; return its exit status.

    Returns None when the window no longer exists (for example when
    the session was killed while the task was running).
    """
    while True:
        result = subprocess.run(
            [
                tmux,
                "list-panes",
                "-t",
                window_id,
                "-F",
                "#{pane_dead} #{pane_dead_status}",
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return None
        line = result.stdout.strip()
        if line:
            dead, _, status = line.partition(" ")
            if dead == "1":
                try:
                    return int(status)
                except ValueError:
                    return 1
        time.sleep(POLL_SECONDS)


def rename_window(tmux: str, window_id: str, name: str) -> None:
    """Rename a finished task window to show its outcome."""
    subprocess.run(
        [tmux, "rename-window", "-t", window_id, name],
        capture_output=True,
    )


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    opencode = resolve_opencode()
    tmux = resolve_tmux()
    tasks = json.loads(CONFIG.read_text(encoding="utf-8"))["tasks"]
    stamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%S")

    session = None
    needs_new_session = False
    if tmux:
        session, needs_new_session = resolve_target_session(tmux)

    if dry_run:
        print(f"opencode binary: {opencode}")
        if tmux:
            state = "new session" if needs_new_session else "existing session"
            print(f"tmux binary: {tmux} (target: {session}, {state})")
        else:
            print("tmux binary: not found (headless mode)")
        for task in tasks:
            state = "enabled" if task.get("enabled", True) else "disabled"
            print(f"\n# {task['name']} ({state}, cwd={task['dir']})")
            cmd = build_command(opencode, task)
            if tmux:
                log_path = LOG_DIR / f"{stamp}-{task['name']}.log"
                print(build_window_command(tmux, cmd, log_path))
            else:
                print(" ".join(repr(part) for part in cmd))
        return 0

    LOG_DIR.mkdir(parents=True, exist_ok=True)

    env = dict(os.environ)
    bin_dir = str(pathlib.Path(opencode).resolve().parent)
    env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "")

    windows = []
    headless = []
    for task in tasks:
        name = task["name"]
        if not task.get("enabled", True):
            print(f"[{stamp}] skip {name} (disabled)", flush=True)
            continue

        cmd = build_command(opencode, task)
        log_path = LOG_DIR / f"{stamp}-{name}.log"
        window_id = None
        if tmux:
            window_id = create_window(
                tmux,
                session,
                needs_new_session,
                name,
                task,
                build_window_command(tmux, cmd, log_path),
            )
            if window_id:
                needs_new_session = False
                print(
                    f"[{stamp}] start {name} -> tmux window {window_id} "
                    f"in session {session}, log {log_path}",
                    flush=True,
                )
                windows.append((name, window_id))
            else:
                print(
                    f"[{stamp}] {name}: tmux window creation failed, "
                    "running headless",
                    flush=True,
                )
        if not window_id:
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
            headless.append((name, proc, log))

    failed = 0
    for name, window_id in windows:
        rc = wait_for_window(tmux, window_id)
        if rc is None:
            print(
                f"[{stamp}] {name}: window vanished (session killed?), "
                "counted as failure",
                flush=True,
            )
            failed += 1
            continue
        suffix = "done" if rc == 0 else "fail"
        rename_window(tmux, window_id, f"{WINDOW_PREFIX}-{name}-{suffix}")
        print(f"[{stamp}] {name}: exit {rc}", flush=True)
        if rc != 0:
            failed += 1
    for name, proc, log in headless:
        rc = proc.wait()
        log.close()
        print(f"[{stamp}] {name}: exit {rc}", flush=True)
        if rc != 0:
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
