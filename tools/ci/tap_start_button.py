#!/usr/bin/env python3
"""Locate and tap the Arabic start-journey button from a captured landscape screenshot."""
from pathlib import Path
import subprocess
import sys
from PIL import Image

if len(sys.argv) != 2:
    raise SystemExit("usage: tap_start_button.py CHARACTER_SELECT.png")
image_path = Path(sys.argv[1])
image = Image.open(image_path).convert("RGB")
width, height = image.size
if width <= height:
    raise SystemExit(f"Expected a landscape screenshot, got {width}x{height}.")

# LegendIntro.gd styles the start button with #9b641d. Search only the
# lower panel where the captured Arabic start button actually appears.
target = (155, 100, 29)
tolerance = 22
x0, x1 = int(width * 0.01), int(width * 0.99)
y0, y1 = int(height * 0.78), int(height * 0.99)
xs, ys = [], []
pixels = image.load()
for y in range(y0, y1):
    for x in range(x0, x1):
        pixel = pixels[x, y]
        if all(abs(pixel[channel] - target[channel]) <= tolerance for channel in range(3)):
            xs.append(x)
            ys.append(y)
if not xs:
    raise SystemExit("Arabic start button color #9b641d was not found; refusing a blind tap.")
bounds = (min(xs), min(ys), max(xs), max(ys))
left, top, right, bottom = bounds
box_width, box_height = right - left + 1, bottom - top + 1
if box_width < width * 0.60 or not (24 <= box_height <= 160):
    raise SystemExit(f"Detected gold region is not a plausible start button: bounds={bounds}.")

# Confirm the Arabic button label itself is present in the center of the detected button.
label_x0, label_x1 = int(width * 0.45), int(width * 0.55)
label_y0, label_y1 = max(top, int(height * 0.88)), min(bottom + 1, int(height * 0.96))
label_pixels = 0
for y in range(label_y0, label_y1):
    for x in range(label_x0, label_x1):
        red, green, blue = pixels[x, y]
        low, high = min(red, green, blue), max(red, green, blue)
        if low > 175 and high - low < 80:
            label_pixels += 1
if label_pixels < 100:
    raise SystemExit(f"Arabic start-button label was not verified ({label_pixels} bright pixels); refusing a tap.")

center_x, center_y = (left + right) // 2, (top + bottom) // 2
print(
    f"SCREENSHOT-GUIDED START BUTTON: image={width}x{height}; bounds={bounds}; "
    f"Arabic-label-pixels={label_pixels}; tap=({center_x},{center_y})",
    flush=True,
)
subprocess.run(["adb", "shell", "input", "tap", str(center_x), str(center_y)], check=True)
