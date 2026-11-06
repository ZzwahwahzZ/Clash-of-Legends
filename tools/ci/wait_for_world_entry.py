#!/usr/bin/env python3
"""Poll the real class-select -> world transition and preserve blocked-state evidence."""
from pathlib import Path
import json
import subprocess
import sys
import time

if len(sys.argv) != 3:
    raise SystemExit("usage: wait_for_world_entry.py CHARACTER_SELECT.png OUTPUT_DIR")

reference = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
output_dir.mkdir(parents=True, exist_ok=True)
current = output_dir / "world-entry.png"
status_path = output_dir / "world-entry-status.json"
logcat_path = output_dir / "entry-logcat.txt"


def capture_screen() -> None:
    subprocess.run(
        ["adb", "shell", "screencap", "-p", "/sdcard/clash-world-entry.png"],
        check=True,
    )
    subprocess.run(
        ["adb", "pull", "/sdcard/clash-world-entry.png", str(current)],
        check=True,
    )


def save_status(status: str, attempt: int, detail: str, logcat: str) -> None:
    logcat_path.write_text(logcat, encoding="utf-8", errors="replace")
    status_path.write_text(
        json.dumps(
            {
                "status": status,
                "attempt": attempt,
                "wait_seconds": attempt * 10,
                "detail": detail,
                "gameplay_controls_tested": False,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


last_logcat = ""
for attempt in range(1, 19):
    time.sleep(10)
    logcat = subprocess.run(
        ["adb", "logcat", "-d", "-t", "5000"],
        check=True,
        capture_output=True,
        text=True,
        errors="replace",
    )
    last_logcat = logcat.stdout
    blocked = next(
        (
            line
            for line in last_logcat.splitlines()
            if "WORLD_ENTRY_PREFLIGHT_BLOCKED_BEFORE_DOWNLOAD:" in line
            or "WORLD_ENTRY_BLOCKED:" in line
        ),
        None,
    )
    if blocked:
        capture_screen()
        save_status("blocked_by_verified_content_gate", attempt, blocked, last_logcat)
        print("ANDROID WORLD ENTRY BLOCKED BY VERIFIED-CONTENT GATE: " + blocked, flush=True)
        raise SystemExit(3)

    capture_screen()
    result = subprocess.run(
        [
            sys.executable,
            "tools/ci/assert_world_transition.py",
            str(reference),
            str(current),
        ],
        check=False,
    )
    if result.returncode == 0:
        save_status("entered_world", attempt, "World transition visually verified.", last_logcat)
        print(f"ANDROID WORLD ENTRY VERIFIED after {attempt * 10} seconds.")
        raise SystemExit(0)
    if result.returncode != 2:
        save_status("transition_assertion_error", attempt, f"assert_world_transition.py exited {result.returncode}", last_logcat)
        raise SystemExit(result.returncode)
    print(f"World is still loading ({attempt}/18).", flush=True)

save_status("timeout", 18, "World entry did not complete within 180 seconds.", last_logcat)
raise SystemExit("World entry did not complete within 180 seconds; refusing a false positive.")
