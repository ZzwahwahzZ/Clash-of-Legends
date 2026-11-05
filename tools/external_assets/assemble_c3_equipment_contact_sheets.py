#!/usr/bin/env python3
"""Assemble family contact sheets from Blender diagnostic renders."""
import json, math, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

report = Path(sys.argv[1])
data = json.loads(report.read_text(encoding="utf-8"))
out_dir = report.parent
font = ImageFont.load_default()
families = {}
for row in data["records"]:
    if row.get("status") != "RENDERED_DIAGNOSTIC":
        continue
    families.setdefault(row["family"], []).append(row)

def sheet(rows, output, title):
    cols, cell_w, cell_h, image_h, title_h = 4, 230, 260, 220, 34
    rows_n = math.ceil(len(rows) / cols)
    canvas = Image.new("RGB", (cols * cell_w, title_h + rows_n * cell_h), (24, 27, 34))
    draw = ImageDraw.Draw(canvas)
    draw.text((12, 10), f"{title} — {len(rows)} candidates (diagnostic only)", fill=(240, 240, 245), font=font)
    for i, row in enumerate(rows):
        x = (i % cols) * cell_w
        y = title_h + (i // cols) * cell_h
        im = Image.open(row["preview"]).convert("RGB")
        im.thumbnail((image_h, image_h))
        canvas.paste(im, (x + (cell_w - im.width) // 2, y))
        label = f'{row["family"]} / {Path(row["source"]).stem}'
        draw.text((x + 8, y + image_h + 8), label[:36], fill=(235, 235, 235), font=font)
        draw.text((x + 8, y + image_h + 22), f'v={row["vertex_count"]} f={row["polygon_count"]} uv={row["uv_layer_count"]} mat={row["material_slot_count"]}', fill=(180, 190, 205), font=font)
    canvas.save(output)

for family, rows in families.items():
    sheet(rows, out_dir / f"contact-{family}.jpg", family)
all_rows = [row for fam in sorted(families) for row in families[fam]]
sheet(all_rows, out_dir / "contact-all-equipment.jpg", "All C3 equipment")
print("CONTACT_SHEETS_OK", len(all_rows), sorted(families))
