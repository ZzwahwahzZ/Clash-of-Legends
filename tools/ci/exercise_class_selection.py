#!/usr/bin/env python3
"""Exercise the 11 Arabic-first class buttons using the captured landscape layout.

Coordinates are derived from the actual screenshot dimensions and the inspected
RTL three-column/two-row ScrollContainer layout. Every tap must change the
selected-class status region; no blind tap is counted as a pass.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops

CLASSES = [
    ("warrior", "محارب", 0, 0),
    ("trojan", "ترجمان", 1, 0),
    ("archer", "رامٍ", 2, 0),
    ("ninja", "نينجا", 0, 1),
    ("monk", "راهب", 1, 1),
    ("pirate", "قرصان", 2, 1),
    ("dragon_warrior", "محارب التنين", 0, 2),
    ("windwalker", "سائر الرياح", 1, 2),
    ("thunderstriker", "صاعق", 2, 2),
    ("water_taoist", "طاووس الماء", 0, 3),
    ("fire_taoist", "طاووس النار", 1, 3),
]


def adb(*args: str) -> str:
    result = subprocess.run(
        ["adb", *args], check=True, capture_output=True, text=True, errors="replace"
    )
    return result.stdout


def capture(output_dir: Path, name: str) -> Image.Image:
    remote = f"/sdcard/{name}"
    adb("shell", "screencap", "-p", remote)
    local = output_dir / name
    adb("pull", remote, str(local))
    return Image.open(local).convert("RGB")


def tap(point: tuple[int, int]) -> None:
    adb("shell", "input", "tap", str(point[0]), str(point[1]))
    time.sleep(0.45)


def swipe(start: tuple[int, int], end: tuple[int, int], duration_ms: int = 500) -> None:
    adb(
        "shell", "input", "swipe", str(start[0]), str(start[1]),
        str(end[0]), str(end[1]), str(duration_ms)
    )
    time.sleep(0.7)


def status_crop(image: Image.Image) -> Image.Image:
    width, height = image.size
    return image.crop((int(width * 0.35), int(height * 0.62), int(width * 0.65), int(height * 0.68)))


def grid_crop(image: Image.Image) -> Image.Image:
    width, height = image.size
    return image.crop((int(width * 0.01), int(height * 0.66), int(width * 0.99), int(height * 0.84)))


def grid_text_mask(image: Image.Image) -> Image.Image:
    """Keep bright class-label glyphs; selection-color changes alone cannot fake a scroll."""
    gray = grid_crop(image).convert("L")
    return gray.point(lambda value: 255 if value >= 170 else 0)


def changed_pixels(before: Image.Image, after: Image.Image, threshold: int = 24) -> int:
    if before.size != after.size:
        return max(before.width * before.height, after.width * after.height)
    diff = ImageChops.difference(before, after).convert("RGB")
    count = 0
    for red, green, blue in diff.getdata():
        if red + green + blue >= threshold:
            count += 1
    return count


def scrollbar_thumb(image: Image.Image) -> tuple[int, int] | None:
    """Locate the narrow gray scrollbar thumb visible at the RTL panel's left edge."""
    width, height = image.size
    x0, x1 = 10, min(45, width // 12)
    y0, y1 = int(height * 0.66), int(height * 0.84)
    active_rows: list[int] = []
    pixels = image.load()
    for y in range(y0, y1):
        gray_hits = 0
        for x in range(x0, x1):
            red, green, blue = pixels[x, y]
            if max(red, green, blue) - min(red, green, blue) <= 18 and 85 <= (red + green + blue) // 3 <= 205:
                gray_hits += 1
        if gray_hits >= 3:
            active_rows.append(y)
    if not active_rows:
        return None
    runs: list[list[int]] = []
    current = [active_rows[0]]
    for value in active_rows[1:]:
        if value <= current[-1] + 2:
            current.append(value)
        else:
            runs.append(current)
            current = [value]
    runs.append(current)
    best = max(runs, key=len)
    if len(best) < 12:
        return None
    return ((x0 + x1) // 2, (best[0] + best[-1]) // 2)


def class_point(image: Image.Image, column: int, row: int) -> tuple[int, int]:
    width, height = image.size
    # RTL: column 0 is the rightmost cell, column 2 is the leftmost cell.
    x_ratios = (5.0 / 6.0, 0.5, 1.0 / 6.0)
    y_ratios = (0.735, 0.818)
    return (round(width * x_ratios[column]), round(height * y_ratios[row % 2]))


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: exercise_class_selection.py CHARACTER_SELECT.png OUTPUT_DIR")
    reference_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)
    current = Image.open(reference_path).convert("RGB")
    width, height = current.size
    if width <= height or width < 1800 or height < 800:
        raise SystemExit(f"Expected a captured landscape phone frame, got {width}x{height}.")

    evidence: dict[str, Any] = {
        "screenshot_size": [width, height],
        "coordinate_space": "captured landscape framebuffer; positions normalized to this screenshot",
        "default_class": {"id": "warrior", "arabic_label": "محارب", "selected_by_default": True, "screenshot": reference_path.name},
        "start_button": {"tap": [round(width * 0.5), round(height * 0.907)], "derived_from": "measured start-button center in the captured landscape class-select screenshot"},
        "classes": [],
        "scroll": [],
        "semantic_ocr": "not_run; each tap is verified by a changed selected-class label region and screenshot evidence",
    }

    # Warrior is already selected by the screen's default state. Verify the other
    # five visible controls before moving the scroll container.
    for class_id, arabic, column, row in CLASSES[1:6]:
        point = class_point(current, column, row)
        before_status = status_crop(current)
        tap(point)
        current = capture(output_dir, f"class-{class_id}.png")
        delta = changed_pixels(before_status, status_crop(current))
        if delta < 12:
            raise SystemExit(f"Class button did not update the selected-class label: {class_id} at {point}; changed pixels={delta}")
        evidence["classes"].append({"id": class_id, "arabic_label": arabic, "tap": list(point), "status_changed_pixels": delta, "screenshot": f"class-{class_id}.png"})

    # Scroll using the visible scrollbar thumb when it can be located; otherwise
    # use a drag wholly inside the measured class-grid viewport.
    before_grid = grid_text_mask(current)
    thumb = scrollbar_thumb(current)
    if thumb is not None:
        end_y = min(height - 160, int(height * 0.85))
        swipe(thumb, (thumb[0], end_y), 550)
        method = "detected_scrollbar_thumb"
    else:
        swipe((width // 2, int(height * 0.85)), (width // 2, int(height * 0.68)), 550)
        method = "class_grid_drag_fallback"
    current = capture(output_dir, "class-grid-scrolled.png")
    scroll_delta = changed_pixels(before_grid, grid_text_mask(current))
    thumb_after = scrollbar_thumb(current)
    if thumb_after is not None and thumb_after[1] < int(height * 0.76):
        swipe(thumb_after, (thumb_after[0], min(height - 160, int(height * 0.85))), 550)
        current = capture(output_dir, "class-grid-scrolled.png")
        scroll_delta = changed_pixels(before_grid, grid_text_mask(current))
        thumb_after = scrollbar_thumb(current)
        method += "+thumb_to_bottom"
    if scroll_delta < 300:
        swipe((width // 2, int(height * 0.85)), (width // 2, int(height * 0.68)), 550)
        current = capture(output_dir, "class-grid-scrolled.png")
        scroll_delta = changed_pixels(before_grid, grid_text_mask(current))
        thumb_after = scrollbar_thumb(current)
        method += "+second_grid_drag"
    if scroll_delta < 300:
        raise SystemExit(f"Class list did not visibly scroll; changed class-label pixels={scroll_delta}.")
    if thumb_after is not None and thumb_after[1] < int(height * 0.74):
        raise SystemExit(f"Class list did not reach the lower rows; scrollbar thumb remains at y={thumb_after[1]}.")
    evidence["scroll"].append({"method": method, "scrollbar_thumb_before": list(thumb) if thumb else None, "scrollbar_thumb_after": list(thumb_after) if thumb_after else None, "changed_grid_text_pixels": scroll_delta, "screenshot": "class-grid-scrolled.png"})

    # The bottom of the four-row list exposes Dragon Warrior, Windwalker,
    # Thunderstriker, Water Taoist and Fire Taoist in RTL order.
    for class_id, arabic, column, row in CLASSES[6:]:
        point = class_point(current, column, row)
        before_status = status_crop(current)
        tap(point)
        current = capture(output_dir, f"class-{class_id}.png")
        delta = changed_pixels(before_status, status_crop(current))
        if delta < 12:
            raise SystemExit(f"Scrolled class button did not update the selected-class label: {class_id} at {point}; changed pixels={delta}")
        evidence["classes"].append({"id": class_id, "arabic_label": arabic, "tap": list(point), "status_changed_pixels": delta, "screenshot": f"class-{class_id}.png"})

    # Restore the top of the list and the default Warrior selection before the
    # separate world-entry/content-gate test runs.
    swipe((width // 2, int(height * 0.68)), (width // 2, int(height * 0.85)), 550)
    current = capture(output_dir, "class-grid-restored.png")
    warrior_point = class_point(current, 0, 0)
    before_status = status_crop(current)
    tap(warrior_point)
    current = capture(output_dir, "character-select-final.png")
    restore_delta = changed_pixels(before_status, status_crop(current))
    evidence["restore"] = {"selected": "warrior", "tap": list(warrior_point), "status_changed_pixels": restore_delta, "screenshot": "character-select-final.png"}
    if restore_delta < 12:
        raise SystemExit("Could not restore the default Warrior selection after scrolling.")

    (output_dir / "class-selection-evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output_dir / "class-selection-status.txt").write_text(
        f"PASS: {len(evidence['classes']) + 1} of 11 class buttons responded; default Warrior selection restored.\n"
        "Verification: selected-class status-region pixel change plus one screenshot per class; Arabic OCR was not run.\n",
        encoding="utf-8",
    )
    print(f"CLASS SELECTION VERIFIED: 11 class controls exercised; screenshots saved to {output_dir}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
