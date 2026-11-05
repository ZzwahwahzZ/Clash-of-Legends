#!/usr/bin/env python3
"""Build a provenance-preserving runtime catalog from the verified PCK source index.

This catalogs source files without guessing class, gender, mount identity, equipment
slot, or visual approval. Converted GLBs are merged later as explicit candidates.
"""
from __future__ import annotations

import csv
import json
from pathlib import Path, PurePosixPath

ROOT = Path.cwd()
STAGE = ROOT / "resource_stage"
INDEX = ROOT / "reports" / "resource-source-index.csv"
CATALOG = STAGE / "world" / "resource_catalog.json"
CATEGORIES = (
    "world", "maps", "characters", "monsters", "equipment", "mounts",
    "effects", "animations", "interface", "audio", "models",
)


def main() -> None:
    if not INDEX.is_file():
        raise SystemExit(f"Verified resource source index is missing: {INDEX}")
    assets: dict[str, list[dict]] = {category: [] for category in CATEGORIES}
    missing: list[str] = []
    seen: set[str] = set()
    with INDEX.open("r", encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream):
            category = str(row.get("category", "")).strip()
            staged = str(row.get("staged_path", "")).replace("\\", "/").strip()
            source = str(row.get("source_path", "")).strip()
            if category not in assets or not staged:
                continue
            rel = PurePosixPath(staged)
            if rel.is_absolute() or any(part in ("", ".", "..") for part in rel.parts):
                raise SystemExit(f"Unsafe source-index path: {staged}")
            if not staged.startswith("resource_stage/"):
                raise SystemExit(f"Unexpected staged path outside resource_stage: {staged}")
            if staged in seen:
                continue
            seen.add(staged)
            path = ROOT / Path(*rel.parts)
            if not path.is_file():
                missing.append(staged)
                continue
            expected_size = int(row.get("size_bytes") or 0)
            expected_hash = str(row.get("sha256", "")).lower()
            if path.stat().st_size != expected_size:
                raise SystemExit(f"Catalog source size mismatch: {staged}")
            if len(expected_hash) != 64:
                raise SystemExit(f"Catalog source hash is invalid: {staged}")
            entry = {
                "path": staged,
                "source": source,
                "extension": path.suffix.lower(),
                "size_bytes": expected_size,
                "sha256": expected_hash,
                "mapping_status": "unreviewed",
                "asset_role": "unclassified",
            }
            assets[category].append(entry)
    if not any(assets.values()):
        raise SystemExit("Runtime catalog would be empty.")
    for category in assets:
        assets[category].sort(key=lambda item: item["path"])
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    catalog = {
        "catalog_version": 1,
        "source_release": "resource-packs-v4",
        "provenance_policy": (
            "Paths, source references, byte sizes and SHA-256 values come from the "
            "verified resource-source-index.csv. No identity or visual approval is inferred."
        ),
        "asset_counts": {key: len(value) for key, value in assets.items()},
        "source_index_missing_count": len(missing),
        "source_index_missing_samples": missing[:100],
        "assets": assets,
    }
    CATALOG.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("RUNTIME RESOURCE CATALOG BUILT")
    print(json.dumps(catalog["asset_counts"], ensure_ascii=False, indent=2))
    print(f"Catalog: {CATALOG} | available assets: {sum(map(len, assets.values()))} | indexed paths absent from baseline PCKs: {len(missing)}")


if __name__ == "__main__":
    main()
