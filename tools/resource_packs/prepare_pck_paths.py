#!/usr/bin/env python3
"""Prepare safe extraction paths from the already verified resource-packs-v4 index."""
from __future__ import annotations
import csv
import json
import shutil
from collections import Counter
from pathlib import Path, PurePosixPath

ROOT = Path.cwd()
SOURCE = ROOT / "resource-source-index.csv"
REPORTS = ROOT / "reports"
BUILD = ROOT / "build"
KNOWN_CATEGORIES = {
    "animations", "audio", "characters", "effects", "equipment",
    "interface", "maps", "models", "monsters", "mounts", "world",
}

def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit("resource-source-index.csv is missing; download it from resource-packs-v4.")
    REPORTS.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE, REPORTS / "resource-source-index.csv")

    entries = []
    extension_counts: Counter[str] = Counter()
    category_counts: Counter[str] = Counter()
    archive_counts: Counter[str] = Counter()
    samples = []
    sample_extensions = {".ini", ".scene", ".tme", ".ani", ".dat", ".fui", ".tpd", ".tpi", ".wdb", ".otherdata", ".pul", ".pux", ".dmap", ".c3", ".pvr", ".mjp"}

    with SOURCE.open("r", encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream):
            category = (row.get("category") or "").strip()
            staged = (row.get("staged_path") or "").replace("\\", "/").strip()
            source_path = (row.get("source_path") or "").strip()
            if category not in KNOWN_CATEGORIES or not staged.startswith("resource_stage/"):
                continue
            rel = PurePosixPath(staged)
            if rel.is_absolute() or any(part in ("", ".", "..") for part in rel.parts):
                raise SystemExit(f"Unsafe staged path in source index: {staged}")
            if any(ord(ch) < 32 or ord(ch) == 127 for ch in source_path):
                continue
            size = int(row.get("size_bytes") or 0)
            digest = (row.get("sha256") or "").lower()
            if size < 0 or (len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest)):
                raise SystemExit(f"Invalid size/hash metadata for {staged}")
            inner = source_path.split("!")[-1].replace("\\", "/")
            ext = PurePosixPath(inner).suffix.lower() or "<none>"
            extension_counts[ext] += 1
            category_counts[category] += 1
            archive_counts[row.get("source_archive") or "<unknown>"] += 1
            entries.append({
                "path": staged,
                "category": category,
                "size_bytes": size,
                "sha256": digest,
                "source": source_path,
            })
            if ext in sample_extensions and sum(1 for item in samples if item["extension"] == ext) < 2:
                samples.append({"extension": ext, "path": staged, "source": source_path})

    if not entries:
        raise SystemExit("The v4 source index contains no safe staged paths.")
    entries.sort(key=lambda item: item["path"])
    (BUILD / "resource-pck-paths.json").write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    audit = {
        "baseline_release": "resource-packs-v4",
        "source_index": str(SOURCE),
        "unique_supported_files": len(entries),
        "staged_bytes": sum(item["size_bytes"] for item in entries),
        "category_counts": dict(sorted(category_counts.items())),
        "extension_counts": dict(sorted(extension_counts.items())),
        "source_archive_counts": dict(sorted(archive_counts.items())),
        "extraction_policy": "Files are rehydrated from checksum-verified Godot PCKs; original source paths and SHA-256 provenance remain in resource-source-index.csv.",
    }
    (REPORTS / "source-archive-extension-audit.json").write_text(
        json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    sample_lines = [
        "# Source format samples (rehydrated from resource-packs-v4)",
        "Samples are read from extracted PCK content; binary formats are represented by hex prefixes.",
        "",
    ]
    for item in samples:
        sample_lines.extend([f"## {item['extension']} | {item['source']} | {item['path']}", "Pending extraction.", ""])
    (REPORTS / "source-format-samples.txt").write_text("\n".join(sample_lines), encoding="utf-8")
    print(f"Prepared {len(entries)} safe PCK paths across {len(category_counts)} categories; {sum(item['size_bytes'] for item in entries)} staged bytes.")
    print("PCK categories: " + json.dumps(dict(sorted(category_counts.items()))))

if __name__ == "__main__":
    main()
