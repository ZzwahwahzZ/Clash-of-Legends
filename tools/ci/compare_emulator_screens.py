#!/usr/bin/env python3
"""Assert that two Android emulator screenshots show a meaningful UI transition."""
from __future__ import annotations
import argparse
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

parser = argparse.ArgumentParser()
parser.add_argument("before", type=Path)
parser.add_argument("after", type=Path)
parser.add_argument("region", nargs="?", help="Optional x1,y1,x2,y2 crop in screenshot pixels")
parser.add_argument("--minimum-ratio", type=float, default=0.002)
args = parser.parse_args()

before = Image.open(args.before).convert("RGB")
after = Image.open(args.after).convert("RGB")
if before.size != after.size:
    after = after.resize(before.size, Image.Resampling.BILINEAR)
if args.region:
    try:
        x1, y1, x2, y2 = (int(value) for value in args.region.split(","))
        if not (0 <= x1 < x2 <= before.width and 0 <= y1 < y2 <= before.height):
            raise ValueError("region outside screenshot bounds")
        before = before.crop((x1, y1, x2, y2))
        after = after.crop((x1, y1, x2, y2))
    except Exception as exc:
        raise SystemExit(f"Invalid comparison region: {exc}")
diff = ImageChops.difference(before, after).convert("L")
changed = sum(1 for value in diff.getdata() if value >= 18)
total = diff.width * diff.height
ratio = changed / total if total else 0.0
mean = ImageStat.Stat(diff).mean[0]
print(f"SCREEN TRANSITION: changed_pixels={changed}/{total} ({ratio:.2%}); mean_abs_difference={mean:.2f}")
if ratio < args.minimum_ratio:
    raise SystemExit(f"Screenshots are too similar; expected at least {args.minimum_ratio:.2%} changed pixels.")
print("SCREEN TRANSITION VERIFIED.")
