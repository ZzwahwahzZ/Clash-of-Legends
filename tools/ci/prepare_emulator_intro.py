#!/usr/bin/env python3
"""Dismiss Android's first-run immersive notice and verify the game's intro/class screen.

All taps are derived from a live UIAutomator hierarchy or from the captured game
screenshot. If neither expected state is proved, the helper refuses to tap.
"""
from __future__ import annotations

import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parent
TAP_INTRO = ROOT / "tap_intro_skip.py"
REMOTE_XML = "/sdcard/clash-window-before-intro.xml"
REMOTE_SCREEN = "/sdcard/clash-intro-or-select.png"
REMOTE_AFTER = "/sdcard/clash-character-select.png"
BOUNDS_RE = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


def find_notice_bounds(xml_text: str, width: int, height: int):
    """Return the measured center and bounds for Android's exact 'Got it' control."""
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as exc:
        raise ValueError(f"UIAutomator XML is malformed: {exc}") from exc
    candidates = []
    for node in root.iter("node"):
        labels = {
            node.attrib.get("text", "").strip().casefold(),
            node.attrib.get("content-desc", "").strip().casefold(),
        }
        if "got it" not in labels:
            continue
        match = BOUNDS_RE.fullmatch(node.attrib.get("bounds", ""))
        if not match:
            continue
        x1, y1, x2, y2 = map(int, match.groups())
        if 0 <= x1 < x2 <= width and 0 <= y1 < y2 <= height:
            clickable = node.attrib.get("clickable", "false").casefold() == "true"
            candidates.append((not clickable, x1, y1, x2, y2))
    if not candidates:
        return None
    _, x1, y1, x2, y2 = sorted(candidates)[0]
    return ((x1 + x2) // 2, (y1 + y2) // 2, (x1, y1, x2, y2))


def fullscreen_notice_panel_pixels(image: Image.Image) -> int:
    """Count the distinctive Android 13 fullscreen-notice panel color in its center region."""
    pixels = image.convert("RGB").load()
    width, height = image.size
    x0, x1 = int(width * 0.25), int(width * 0.75)
    y0, y1 = 0, int(height * 0.65)
    count = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            red, green, blue = pixels[x, y]
            if 60 <= red <= 90 and 80 <= green <= 110 and 120 <= blue <= 170:
                count += 1
    return count


def run_adb(*args: str, check: bool = True):
    result = subprocess.run(["adb", *args], capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"adb {' '.join(args)} failed ({result.returncode}): {result.stderr.strip()}")
    return result


def dump_hierarchy(destination: Path):
    result = run_adb("shell", "uiautomator", "dump", REMOTE_XML)
    if "dumped" not in (result.stdout + result.stderr).casefold():
        print("UIAUTOMATOR DUMP: command completed; validating pulled XML.", flush=True)
    run_adb("pull", REMOTE_XML, str(destination))
    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError("UIAutomator hierarchy was not produced; refusing coordinate guesses.")
    return destination.read_text(encoding="utf-8")


def capture(remote: str, destination: Path):
    run_adb("shell", "screencap", "-p", remote)
    run_adb("pull", remote, str(destination))
    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError(f"Screenshot was not captured: {destination}")


def compare_transition(before_path: Path, after_path: Path):
    before = Image.open(before_path).convert("RGB")
    after = Image.open(after_path).convert("RGB")
    if before.size != after.size:
        raise RuntimeError(f"Intro transition screenshots differ in size: {before.size} vs {after.size}")
    region = (600, 250, 1800, 800)
    before = before.crop(region)
    after = after.crop(region)
    diff = ImageChops.difference(before, after).convert("L")
    changed = sum(1 for value in diff.getdata() if value >= 18)
    total = diff.width * diff.height
    ratio = changed / total if total else 0.0
    mean = ImageStat.Stat(diff).mean[0]
    print(f"INTRO TRANSITION: changed_pixels={changed}/{total} ({ratio:.2%}); mean_abs_difference={mean:.2f}", flush=True)
    if ratio < 0.02:
        raise RuntimeError("Cinematic skip did not produce a verified screen transition (minimum 2.00%).")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: prepare_emulator_intro.py EVIDENCE_DIRECTORY", file=sys.stderr)
        return 2
    evidence = Path(sys.argv[1])
    evidence.mkdir(parents=True, exist_ok=True)
    hierarchy_path = evidence / "window-before-intro.xml"
    xml_text = dump_hierarchy(hierarchy_path)

    # Capture dimensions first; the UI hierarchy supplies the exact system-button bounds.
    intro_path = evidence / "intro-or-select.png"
    capture(REMOTE_SCREEN, intro_path)
    image = Image.open(intro_path).convert("RGB")
    width, height = image.size
    if width <= height:
        raise RuntimeError(f"Expected landscape framebuffer, received {width}x{height}.")

    notice = find_notice_bounds(xml_text, width, height)
    panel_pixels = fullscreen_notice_panel_pixels(image)
    if notice is None and panel_pixels >= 50000:
        raise RuntimeError(f"Android fullscreen notice is visible ({panel_pixels} panel pixels), but UIAutomator did not expose a measured 'Got it' control; refusing to tap blindly.")
    if notice is not None:
        (evidence / "immersive-notice.png").write_bytes(intro_path.read_bytes())
        x, y, bounds = notice
        run_adb("shell", "input", "tap", str(x), str(y))
        print(f"ANDROID IMMERSIVE NOTICE DISMISSED FROM UIAUTOMATOR: text='Got it'; bounds={bounds}; tap=({x},{y})", flush=True)
        time.sleep(1.0)
        after_xml_path = evidence / "window-after-notice.xml"
        after_xml = dump_hierarchy(after_xml_path)
        if find_notice_bounds(after_xml, width, height) is not None:
            raise RuntimeError("Android 'Got it' notice remained after the measured tap; refusing to continue.")
        capture(REMOTE_SCREEN, intro_path)
        if fullscreen_notice_panel_pixels(Image.open(intro_path).convert("RGB")) >= 50000:
            raise RuntimeError("Android fullscreen notice panel remains visible after the measured 'Got it' tap.")
    else:
        print(f"ANDROID IMMERSIVE NOTICE: no exact 'Got it' control found and no notice panel detected ({panel_pixels} matching pixels); no system tap issued.", flush=True)

    # tap_intro_skip.py returns 0 only after a measured cinematic skip tap, 2 when
    # the screenshot proves the timed intro already ended and the Arabic start button exists.
    tap = subprocess.run([sys.executable, str(TAP_INTRO), str(intro_path)], capture_output=True, text=True)
    if tap.stdout:
        print(tap.stdout.strip(), flush=True)
    if tap.stderr:
        print(tap.stderr.strip(), file=sys.stderr, flush=True)

    class_path = evidence / "character-select.png"
    if tap.returncode == 0:
        time.sleep(1.0)
        capture(REMOTE_AFTER, class_path)
        compare_transition(intro_path, class_path)
        print("INTRO STATE VERIFIED: cinematic skip tapped from screenshot-derived label bounds.", flush=True)
        return 0
    if tap.returncode == 2:
        class_path.write_bytes(intro_path.read_bytes())
        print("INTRO STATE VERIFIED: Arabic class-select button detected; timed cinematic intro had already ended.", flush=True)
        return 0
    raise RuntimeError(f"Intro/class-select screenshot did not prove an actionable state (tap helper exit={tap.returncode}).")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"EMULATOR INTRO PREPARATION FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)
