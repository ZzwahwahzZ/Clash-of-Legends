#!/usr/bin/env python3
"""Compare Android emulator screenshots to prove UI state transitions."""
import sys
from PIL import Image, ImageChops


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: compare_emulator_screens.py BEFORE AFTER [panel]")
    before = Image.open(sys.argv[1]).convert("RGB")
    after = Image.open(sys.argv[2]).convert("RGB")
    if before.size != after.size:
        raise SystemExit(f"Screenshot size changed: {before.size} -> {after.size}")
    if len(sys.argv) == 4:
        values = tuple(int(value) for value in sys.argv[3].split(","))
        if len(values) != 4:
            raise SystemExit("panel must be left,top,right,bottom")
        before = before.crop(values)
        after = after.crop(values)
    diff = ImageChops.difference(before, after)
    changed = sum(1 for pixel in diff.getdata() if max(pixel) > 12)
    ratio = changed / (diff.width * diff.height)
    print(f"SCREEN TRANSITION CHANGE: {ratio:.3%}")
    if ratio < 0.05:
        raise SystemExit("Screenshot transition was not detected.")


if __name__ == "__main__":
    main()
