#!/usr/bin/env python3
"""Wait for verified first-run PCK installation and a real class-select -> world transition."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("character_select", type=Path)
parser.add_argument("output_dir", type=Path)
parser.add_argument("--timeout-seconds", type=int, default=1200)
parser.add_argument("--poll-seconds", type=int, default=10)
parser.add_argument("--progress-stall-seconds", type=int, default=420)
parser.add_argument("--no-progress-ui-seconds", type=int, default=120)
args = parser.parse_args()

if args.timeout_seconds <= 0 or args.poll_seconds <= 0:
    raise SystemExit("timeout and polling interval must be positive")
args.output_dir.mkdir(parents=True, exist_ok=True)
current = args.output_dir / "world-entry.png"
log_path = args.output_dir / "logcat-world-entry.txt"
assertion = Path("tools/ci/assert_world_transition.py")
start_time = time.monotonic()
last_progress_time = start_time
last_progress_percent = None
no_progress_ui_since = None
attempt = 0


def adb_text(*command):
    result = subprocess.run(["adb", *command], check=False, capture_output=True, text=True, errors="replace")
    return result.stdout + result.stderr


def save_failure_evidence(reason):
    log_path.write_text(adb_text("logcat", "-d", "-t", "16000"), encoding="utf-8", errors="replace")
    for command, filename in [
        (["shell", "dumpsys", "meminfo", "com.zwahwahzz.clashoflegends"], "memory.txt"),
        (["shell", "dumpsys", "gfxinfo", "com.zwahwahzz.clashoflegends"], "graphics.txt"),
        (["shell", "uiautomator", "dump", "/sdcard/clash-window.xml"], None),
    ]:
        result = subprocess.run(["adb", *command], check=False, capture_output=True, text=True, errors="replace")
        if filename:
            (args.output_dir / filename).write_text(result.stdout + result.stderr, encoding="utf-8", errors="replace")
        elif result.returncode == 0:
            subprocess.run(["adb", "pull", "/sdcard/clash-window.xml", str(args.output_dir / "window-hierarchy.xml")], check=False)
    print(reason, flush=True)


while time.monotonic() - start_time < args.timeout_seconds:
    attempt += 1
    time.sleep(args.poll_seconds)

    pid = adb_text("shell", "pidof", "com.zwahwahzz.clashoflegends").strip()
    if not pid:
        save_failure_evidence("ANDROID WORLD ENTRY FAILED: game process exited during resource installation.")
        raise SystemExit(4)

    logcat = adb_text("logcat", "-d", "-t", "5000")
    log_path.write_text(logcat, encoding="utf-8", errors="replace")
    blocked = next((line for line in logcat.splitlines() if "WORLD_ENTRY_BLOCKED:" in line), None)
    if blocked:
        save_failure_evidence("ANDROID WORLD ENTRY BLOCKED BY THE VERIFIED-CONTENT GATE: " + blocked)
        raise SystemExit(3)
    fatal = next((line for line in logcat.splitlines() if re.search(r"FATAL EXCEPTION|Fatal signal|SIGSEGV", line, re.I)), None)
    if fatal:
        save_failure_evidence("ANDROID WORLD ENTRY FAILED BY ANDROID RUNTIME ERROR: " + fatal)
        raise SystemExit(5)

    subprocess.run(["adb", "shell", "screencap", "-p", "/sdcard/clash-world-entry.png"], check=True)
    subprocess.run(["adb", "pull", "/sdcard/clash-world-entry.png", str(current)], check=True, capture_output=True)
    if attempt % 3 == 0:
        shutil.copy2(current, args.output_dir / f"world-entry-progress-{attempt:03d}.png")

    result = subprocess.run(
        [sys.executable, str(assertion), str(args.character_select), str(current)],
        check=False, capture_output=True, text=True, errors="replace",
    )
    if result.stdout:
        print(result.stdout.strip(), flush=True)
    if result.returncode == 0:
        shutil.copy2(current, args.output_dir / "world-entered.png")
        print(f"ANDROID WORLD ENTRY VERIFIED after {int(time.monotonic() - start_time)} seconds.", flush=True)
        raise SystemExit(0)
    if result.returncode != 2:
        save_failure_evidence("WORLD ENTRY ASSERTION FAILED: " + result.stderr.strip())
        raise SystemExit(result.returncode)

    progress_match = re.search(r"RESOURCE DOWNLOAD PROGRESS: ([0-9.]+)%", result.stdout)
    now = time.monotonic()
    if progress_match:
        percent = float(progress_match.group(1))
        no_progress_ui_since = None
        if last_progress_percent is None or abs(percent - last_progress_percent) >= 0.3:
            last_progress_percent = percent
            last_progress_time = now
        elif now - last_progress_time > args.progress_stall_seconds:
            save_failure_evidence(
                f"RESOURCE DOWNLOAD STALLED at {percent:.1f}% for more than {args.progress_stall_seconds} seconds."
            )
            raise SystemExit(6)
    else:
        if no_progress_ui_since is None:
            no_progress_ui_since = now
        elif now - no_progress_ui_since > args.no_progress_ui_seconds:
            save_failure_evidence(
                "WORLD ENTRY DID NOT COMPLETE: loading progress bar disappeared, but the Arabic start button remains visible."
            )
            raise SystemExit(7)

    elapsed = int(now - start_time)
    print(f"World entry pending ({elapsed}s elapsed; attempt {attempt}).", flush=True)

save_failure_evidence(f"ANDROID WORLD ENTRY TIMED OUT after {args.timeout_seconds} seconds.")
raise SystemExit(8)
