#!/usr/bin/env python3
"""Synthetic regression tests for screenshot-driven Android smoke-test helpers."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
ASSERT = ROOT / "assert_world_transition.py"
TAP = ROOT / "tap_start_button.py"
TAP_INTRO = ROOT / "tap_intro_skip.py"
SIZE = (2400, 1080)

with tempfile.TemporaryDirectory(prefix="clash-emulator-helper-test-") as temp:
    temp_path = Path(temp)
    select = Image.new("RGB", SIZE, (8, 13, 32))
    draw = ImageDraw.Draw(select)
    draw.rectangle((28, 939, 2372, 1013), fill=(155, 100, 29))
    draw.rectangle((1150, 970, 1250, 985), fill=(255, 255, 255))
    select_path = temp_path / "character-select.png"
    select.save(select_path)

    loading = select.copy()
    ImageDraw.Draw(loading).rectangle((905, 944, 2014, 957), fill=(228, 185, 94))
    loading_path = temp_path / "loading.png"
    loading.save(loading_path)

    world_path = temp_path / "world.png"
    Image.new("RGB", SIZE, (22, 31, 45)).save(world_path)

    progress = subprocess.run([sys.executable, str(ASSERT), str(select_path), str(loading_path)], capture_output=True, text=True)
    assert progress.returncode == 2 and "RESOURCE DOWNLOAD PROGRESS" in progress.stdout, progress.stdout + progress.stderr

    pending = subprocess.run([sys.executable, str(ASSERT), str(select_path), str(select_path)], capture_output=True, text=True)
    assert pending.returncode == 2 and "start button remains visible" in pending.stdout, pending.stdout + pending.stderr

    entered = subprocess.run([sys.executable, str(ASSERT), str(select_path), str(world_path)], capture_output=True, text=True)
    assert entered.returncode == 0 and "WORLD TRANSITION VERIFIED" in entered.stdout, entered.stdout + entered.stderr

    fake_bin = temp_path / "bin"
    fake_bin.mkdir()
    adb = fake_bin / "adb"
    adb.write_text("#!/bin/sh\nprintf '%s\\n' \"$*\" > \"$CLASH_FAKE_ADB_LOG\"\n", encoding="utf-8")
    adb.chmod(0o755)
    env = os.environ.copy()
    env["PATH"] = str(fake_bin) + os.pathsep + env.get("PATH", "")
    env["CLASH_FAKE_ADB_LOG"] = str(temp_path / "adb-args.txt")
    tapped = subprocess.run([sys.executable, str(TAP), str(select_path)], env=env, capture_output=True, text=True)
    assert tapped.returncode == 0, tapped.stdout + tapped.stderr
    args = Path(env["CLASH_FAKE_ADB_LOG"]).read_text(encoding="utf-8").strip()
    assert args == "shell input tap 1200 976", args
    assert "bounds=(28, 939, 2372, 1013)" in tapped.stdout, tapped.stdout

    intro = Image.new("RGB", SIZE, (8, 13, 32))
    intro_draw = ImageDraw.Draw(intro)
    intro_draw.rectangle((1000, 360, 1400, 420), fill=(255, 150, 45))  # cinematic title anchor
    intro_draw.rectangle((1060, 685, 1340, 710), fill=(245, 245, 245))  # centered skip label
    intro_path = temp_path / "intro.png"
    intro.save(intro_path)

    black_path = temp_path / "black.png"
    Image.new("RGB", SIZE, (0, 0, 0)).save(black_path)

    intro_tap = subprocess.run([sys.executable, str(TAP_INTRO), str(intro_path)], env=env, capture_output=True, text=True)
    assert intro_tap.returncode == 0, intro_tap.stdout + intro_tap.stderr
    args = Path(env["CLASH_FAKE_ADB_LOG"]).read_text(encoding="utf-8").strip().splitlines()[-1]
    assert args == "shell input tap 1200 697", args
    assert "SCREENSHOT-GUIDED CINEMATIC SKIP" in intro_tap.stdout, intro_tap.stdout

    before = len(Path(env["CLASH_FAKE_ADB_LOG"]).read_text(encoding="utf-8").splitlines())
    auto_dismissed = subprocess.run([sys.executable, str(TAP_INTRO), str(select_path)], env=env, capture_output=True, text=True)
    assert auto_dismissed.returncode == 2, auto_dismissed.stdout + auto_dismissed.stderr
    after = len(Path(env["CLASH_FAKE_ADB_LOG"]).read_text(encoding="utf-8").splitlines())
    assert before == after, "auto-dismissed screen must not issue a guessed tap"

    no_screen = subprocess.run([sys.executable, str(TAP_INTRO), str(black_path)], env=env, capture_output=True, text=True)
    assert no_screen.returncode != 0 and "no tap issued" in no_screen.stderr, no_screen.stdout + no_screen.stderr

print("ANDROID EMULATOR HELPER TESTS PASSED: RTL progress detection, pending-state rejection, world-transition acceptance, screenshot-derived intro skip, auto-dismiss recognition, black-frame rejection and screenshot-derived start-button tap.")
