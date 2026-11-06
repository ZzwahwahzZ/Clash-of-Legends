#!/usr/bin/env python3
"""Poll Android screenshots until the real character-select -> world transition is visible."""
from pathlib import Path
import subprocess
import sys
import time

if len(sys.argv) != 3:
    raise SystemExit("usage: wait_for_world_entry.py CHARACTER_SELECT.png OUTPUT_DIR")

reference = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
output_dir.mkdir(parents=True, exist_ok=True)
current = output_dir / "world-entry.png"

for attempt in range(1, 19):
    time.sleep(10)
    subprocess.run(
        ["adb", "shell", "screencap", "-p", "/sdcard/clash-world-entry.png"],
        check=True,
    )
    subprocess.run(
        ["adb", "pull", "/sdcard/clash-world-entry.png", str(current)],
        check=True,
    )
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
        print(f"ANDROID WORLD ENTRY VERIFIED after {attempt * 10} seconds.")
        raise SystemExit(0)
    if result.returncode != 2:
        raise SystemExit(result.returncode)
    print(f"World is still loading ({attempt}/18).", flush=True)

raise SystemExit("World entry did not complete within 180 seconds; refusing a false positive.")
