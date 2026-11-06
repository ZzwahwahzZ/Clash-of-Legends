#!/usr/bin/env python3
"""Distinguish resource-pack download progress from a completed world transition."""
from pathlib import Path
import sys
from PIL import Image

if len(sys.argv) != 3:
    raise SystemExit("usage: assert_world_transition.py CHARACTER_SELECT.png CURRENT.png")
reference = Image.open(Path(sys.argv[1])).convert("RGB")
current = Image.open(Path(sys.argv[2])).convert("RGB")
if reference.size != current.size:
    raise SystemExit(f"Screenshot dimensions differ: {reference.size} vs {current.size}")
width, height = current.size

# LegendIntro.gd anchors its integrated ProgressBar at y=0.88 and uses #e4b95e.
# Under the Arabic RTL locale the bar fills from right to left.
track_x0, track_x1 = int(width * 0.16), int(width * 0.84)
center_y = int(height * 0.88)
pixels = current.load()
active_columns = []
for x in range(track_x0, track_x1):
    hits = 0
    for y in range(max(0, center_y - 9), min(height, center_y + 10)):
        red, green, blue = pixels[x, y]
        if abs(red - 228) <= 24 and abs(green - 185) <= 24 and abs(blue - 94) <= 24:
            hits += 1
    if hits >= 3:
        active_columns.append(x)

longest = 0
if active_columns:
    run_start = previous = active_columns[0]
    for x in active_columns[1:]:
        if x > previous + 1:
            longest = max(longest, previous - run_start + 1)
            run_start = x
        previous = x
    longest = max(longest, previous - run_start + 1)
track_width = track_x1 - track_x0
if longest >= max(12, int(track_width * 0.005)):
    ratio = longest / track_width
    print(f"RESOURCE DOWNLOAD PROGRESS: {ratio * 100:.1f}% (RTL fill {longest}/{track_width} px).")
    raise SystemExit(2)

# The start label remains visible behind the loading overlay. Check it only
# after the gold progress bar disappears.
x1, y1, x2, y2 = int(width * 0.45), int(height * 0.89), int(width * 0.55), int(height * 0.94)

def glyph_mask(image):
    source = image.load()
    mask = []
    for y in range(y1, y2):
        for x in range(x1, x2):
            red, green, blue = source[x, y]
            low, high = min(red, green, blue), max(red, green, blue)
            mask.append(low > 175 and high - low < 70)
    return mask

reference_mask = glyph_mask(reference)
current_mask = glyph_mask(current)
reference_count = sum(reference_mask)
if reference_count < 300:
    raise SystemExit(f"Reference Arabic start label is not detectable ({reference_count} pixels).")
overlap = sum(1 for expected, actual in zip(reference_mask, current_mask) if expected and actual)
ratio = overlap / reference_count
print(f"WORLD TRANSITION ASSERTION: Arabic start-label overlap={ratio:.3f} ({overlap}/{reference_count}).")
if ratio >= 0.55:
    print("WORLD TRANSITION PENDING: class-select start button remains visible and no loading bar is present.")
    raise SystemExit(2)
print("WORLD TRANSITION VERIFIED: class-select start label is absent; world scene has replaced the intro.")
