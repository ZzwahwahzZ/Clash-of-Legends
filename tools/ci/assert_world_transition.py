#!/usr/bin/env python3
"""Fail the Android smoke test while the character-select start label is still visible."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

if len(sys.argv) != 3:
    raise SystemExit("usage: assert_world_transition.py CHARACTER_SELECT.png CURRENT.png")

reference = np.asarray(Image.open(Path(sys.argv[1])).convert("RGB"), dtype=np.int16)
current = np.asarray(Image.open(Path(sys.argv[2])).convert("RGB"), dtype=np.int16)
if reference.shape != current.shape:
    raise SystemExit(f"Screenshot dimensions differ: {reference.shape} vs {current.shape}")

# Fixed landscape ROI around the Arabic 'ابدأ رحلتك' label in the start button.
# Compare bright, low-chroma glyph pixels rather than the button fill/progress bar.
x1, y1, x2, y2 = 1080, 960, 1320, 1005

def glyph_mask(image):
    region = image[y1:y2, x1:x2]
    return (region.min(axis=2) > 175) & ((region.max(axis=2) - region.min(axis=2)) < 70)

reference_mask = glyph_mask(reference)
current_mask = glyph_mask(current)
reference_count = int(reference_mask.sum())
if reference_count < 300:
    raise SystemExit(f"Reference start-button label is not detectable ({reference_count} pixels).")

overlap = int((reference_mask & current_mask).sum())
ratio = overlap / reference_count
print(f"WORLD TRANSITION ASSERTION: start-label template overlap={ratio:.3f} ({overlap}/{reference_count})")
if ratio >= 0.55:
    print("WORLD TRANSITION PENDING: character-select start button is still visible.")
    raise SystemExit(2)

print("WORLD TRANSITION VERIFIED: character-select start label is no longer visible.")
