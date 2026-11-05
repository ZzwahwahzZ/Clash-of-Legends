#!/usr/bin/env python3
"""Merge validated C3 GLB conversions into the runtime resource catalog."""
import hashlib, json, shutil
from pathlib import Path

root = Path.cwd()
source_root = root / "build/c3-glb"
stage_root = root / "resource_stage"
catalog_path = stage_root / "world/resource_catalog.json"
if not source_root.is_dir():
    raise SystemExit("Converted C3 GLB directory is missing.")
if not catalog_path.is_file():
    raise SystemExit("Prepared runtime resource catalog is missing.")
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
assets = catalog.setdefault("assets", {})
existing_hashes = {
    row.get("sha256")
    for rows in assets.values() if isinstance(rows, list)
    for row in rows if isinstance(row, dict)
}
added = []
for source in sorted(source_root.rglob("*.glb")):
    relative = source.relative_to(source_root)
    if len(relative.parts) < 2:
        continue
    category = relative.parts[0]
    if category not in {"characters", "monsters", "equipment", "world"}:
        continue
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest in existing_hashes:
        continue
    destination = stage_root / category / "converted_c3" / Path(*relative.parts[1:])
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    entry = {
        "path": destination.relative_to(root).as_posix(),
        "source": "C3 conversion: " + relative.as_posix(),
        "extension": ".glb",
        "size_bytes": destination.stat().st_size,
        "sha256": digest,
    }
    assets.setdefault(category, []).append(entry)
    existing_hashes.add(digest)
    added.append({"category": category, "path": entry["path"], "size_bytes": entry["size_bytes"]})
catalog["asset_counts"] = {key: len(value) for key, value in assets.items() if isinstance(value, list)}
catalog["catalog_version"] = int(catalog.get("catalog_version", 1)) + 1
catalog["c3_conversion"] = {
    "format": "glb",
    "source": "validated C3/PVR conversion",
    "models_added": len(added),
    "category_counts": {key: sum(1 for item in added if item["category"] == key) for key in sorted({item["category"] for item in added})},
}
catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
report = {"models_added": len(added), "category_counts": catalog["c3_conversion"]["category_counts"], "models": added}
Path("reports").mkdir(exist_ok=True)
Path("reports/c3-runtime-integration.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"models_added": len(added), "category_counts": catalog["c3_conversion"]["category_counts"]}, ensure_ascii=False, indent=2))
if not added:
    raise SystemExit("No converted C3 models were merged into the runtime catalog.")
