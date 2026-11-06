#!/usr/bin/env python3
"""Fail the Android smoke test while the character-select start label is still visible."""
from pathlib import Path
import sys
from PIL import Image

if len(sys.argv) != 3:
    raise SystemExit("usage: assert_world_transition.py CHARACTER_SELECT.png CURRENT.png")

reference = Image.open(Path(sys.argv[1])).convert("RGB")
current = Image.open(Path(sys.argv[2])).convert("RGB")
if reference.size != current.size:
    raise SystemExit(f"Screenshot dimensions differ: {reference.size} vs {current.size}")

# Fixed landscape ROI around the Arabic 'ابدأ رحلتك' label in the start button.
# Compare bright, low-chroma glyph pixels rather than the button fill/progress bar.
x1, y1, x2, y2 = 1080, 960, 1320, 1005

def glyph_mask(image):
    pixels = image.load()
    mask = []
    for y in range(y1, y2):
        for x in range(x1, x2):
            red, green, blue = pixels[x, y]
            mask.append(min(red, green, blue) > 175 and max(red, green, blue) - min(red, green, blue) < 70)
    return mask

reference_mask = glyph_mask(reference)
current_mask = glyph_mask(current)
reference_count = sum(reference_mask)
if reference_count < 300:
    raise SystemExit(f"Reference start-button label is not detectable ({reference_count} pixels).")

overlap = sum(1 for expected, actual in zip(reference_mask, current_mask) if expected and actual)
ratio = overlap / reference_count
print(f"WORLD TRANSITION ASSERTION: start-label template overlap={ratio:.3f} ({overlap}/{reference_count})")
if ratio >= 0.55:
    print("WORLD TRANSITION PENDING: character-select start button is still visible.")
    raise SystemExit(2)

print("WORLD TRANSITION VERIFIED: character-select start label is no longer visible.")
