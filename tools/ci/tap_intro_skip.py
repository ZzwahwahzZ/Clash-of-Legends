#!/usr/bin/env python3
"""Detect and tap LegendIntro's centered Arabic skip control from a captured landscape screenshot.

Exit codes:
  0: cinematic skip control was detected from pixels and tapped.
  2: intro had already auto-dismissed; the class-select start control was verified.
  other: screenshot did not prove either expected state; no tap was issued.
"""
from pathlib import Path
import subprocess
import sys
from PIL import Image


def neutral_bright(pixel):
    low, high = min(pixel), max(pixel)
    return low > 175 and high - low < 80


def gold_title(pixel):
    red, green, blue = pixel
    return red > 170 and 80 < green < 220 and blue < 135 and red - blue > 65


def count_pixels(pixels, box, predicate):
    x0, y0, x1, y1 = box
    count = 0
    xs, ys = [], []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if predicate(pixels[x, y]):
                count += 1
                xs.append(x)
                ys.append(y)
    return count, xs, ys


def start_button_present(pixels, width, height):
    x0, x1 = int(width * .01), int(width * .99)
    y0, y1 = int(height * .78), int(height * .99)
    target = (155, 100, 29)
    xs, ys = [], []
    for y in range(y0, y1):
        for x in range(x0, x1):
            pixel = pixels[x, y]
            if all(abs(pixel[channel] - target[channel]) <= 22 for channel in range(3)):
                xs.append(x)
                ys.append(y)
    if not xs:
        return False
    bounds = (min(xs), min(ys), max(xs), max(ys))
    box_width = bounds[2] - bounds[0] + 1
    box_height = bounds[3] - bounds[1] + 1
    if box_width < width * .60 or not (24 <= box_height <= 160):
        return False
    label_box = (int(width*.45), max(bounds[1], int(height*.88)), int(width*.55), min(bounds[3]+1, int(height*.96)))
    label_count, _, _ = count_pixels(pixels, label_box, neutral_bright)
    return label_count >= 100


if len(sys.argv) != 2:
    raise SystemExit("usage: tap_intro_skip.py INTRO_OR_CLASS_SELECT.png")
path = Path(sys.argv[1])
image = Image.open(path).convert("RGB")
width, height = image.size
if width <= height:
    raise SystemExit(f"Expected landscape screenshot, got {width}x{height}; no tap issued.")
pixels = image.load()

# LegendIntro's cinematic title and skip label are centered at y≈0.38 and
# y≈0.65 respectively on the 2400x1080 landscape framebuffer.
title_box = (int(width*.35), int(height*.28), int(width*.65), int(height*.48))
title_hits, _, _ = count_pixels(pixels, title_box, gold_title)
label_box = (int(width*.35), int(height*.62), int(width*.65), int(height*.70))
label_hits, xs, ys = count_pixels(pixels, label_box, neutral_bright)
if title_hits >= 250 and label_hits >= 180:
    bounds = (min(xs), min(ys), max(xs), max(ys))
    box_width = bounds[2]-bounds[0]+1
    box_height = bounds[3]-bounds[1]+1
    if width*.07 <= box_width <= width*.30 and height*.012 <= box_height <= height*.07:
        tap_x = (bounds[0]+bounds[2])//2
        tap_y = (bounds[1]+bounds[3])//2
        print(f"SCREENSHOT-GUIDED CINEMATIC SKIP: image={width}x{height}; title-gold-pixels={title_hits}; label-bounds={bounds}; label-pixels={label_hits}; tap=({tap_x},{tap_y})", flush=True)
        subprocess.run(["adb", "shell", "input", "tap", str(tap_x), str(tap_y)], check=True)
        sys.exit(0)

# If the timed intro fade already completed, verify the actual gold start button
# and its bright Arabic label; do not tap a guessed location.
if start_button_present(pixels, width, height):
    print(f"CINEMATIC INTRO ALREADY DISMISSED: class-select start button verified from {width}x{height} screenshot; no tap needed.", flush=True)
    sys.exit(2)

raise SystemExit(f"Neither cinematic skip nor class-select start control was verified (title={title_hits}, center-label={label_hits}); no tap issued.")
