#!/usr/bin/env python3
"""Cross-check every available C3 motion path against conversion outputs."""
import csv, json
from pathlib import Path

motion_path = Path("resource_stage/world/resource_mappings/motion_catalog.json")
audit_path = Path("reports/c3-model-audit.json")
index_path = Path("reports/resource-source-index.csv")
if not motion_path.is_file() or not audit_path.is_file() or not index_path.is_file():
    raise SystemExit("Motion catalog, C3 conversion audit or source index is missing")

motion = json.loads(motion_path.read_text(encoding="utf-8"))
audit = json.loads(audit_path.read_text(encoding="utf-8"))
with index_path.open("r", encoding="utf-8-sig", newline="") as stream:
    index_rows = list(csv.DictReader(stream))

source_by_inner = {}
for row in index_rows:
    inner = row.get("source_path", "").split("!")[-1].replace("\\", "/").lower()
    if inner:
        source_by_inner.setdefault(inner, []).append(row)

def normalize_source(source):
    value = str(source).replace("\\", "/").lower()
    return "c3/" + value.split("/c3/", 1)[1] if "/c3/" in value else value

converted = {}
for row in audit.get("converted", []):
    # Full-character motion POCs are exported from a body C3 plus a separate
    # motion-only C3. Count the external motion source as converted too; using
    # only "source" silently counted the body path and under-reported clips.
    for source_field in ("source", "external_motion_source"):
        inner = normalize_source(row.get(source_field, ""))
        if inner:
            converted[inner] = {**row, "conversion_source_field": source_field}

all_motion_paths = sorted(set(str(p).replace("\\", "/").lower() for p in motion.get("unique_motion_paths", [])))
available = []
source_missing = []
for path in all_motion_paths:
    candidates = source_by_inner.get(path, [])
    staged = [r.get("staged_path", "") for r in candidates if r.get("staged_path")]
    actual = next((p for p in staged if Path(p).is_file()), None)
    if actual:
        available.append(path)
    else:
        source_missing.append(path)

converted_rows = []
missing_conversion = []
no_motion_chunk = []
for path in available:
    row = converted.get(path)
    if row is None:
        missing_conversion.append(path)
        continue
    chunk_count = int(row.get("motion_chunk_count", 0) or 0)
    converted_rows.append({
        "source_path": path,
        "output": row.get("output", ""),
        "glb_bytes": row.get("glb_bytes", 0),
        "motion_chunk_count": chunk_count,
        "mesh_count": row.get("mesh_count", 0),
    })
    if chunk_count <= 0:
        no_motion_chunk.append(path)

if source_missing:
    status = "SOURCE_MOTION_PATHS_MISSING_FROM_EXTRACTED_ASSETS"
elif missing_conversion or no_motion_chunk:
    status = "MOTION_CONVERSION_GAPS_REMAIN"
else:
    status = "ALL_AVAILABLE_MOTION_PATHS_CONVERTED_PENDING_RUNTIME_PLAYBACK"

report = {
    "schema_version": "1.0.0",
    "motion_table_count": len(motion.get("tables", {})),
    "unique_motion_path_count": len(all_motion_paths),
    "source_motion_path_available_count": len(available),
    "source_motion_path_missing_count": len(source_missing),
    "motion_path_converted_count": len(converted_rows),
    "motion_path_missing_conversion_count": len(missing_conversion),
    "converted_without_motion_chunk_count": len(no_motion_chunk),
    "converted_motion_chunk_total": sum(r["motion_chunk_count"] for r in converted_rows),
    "source_missing_samples": source_missing[:100],
    "missing_conversion_samples": missing_conversion[:100],
    "no_motion_chunk_samples": no_motion_chunk[:100],
    "converted_samples": converted_rows[:100],
    "status": status,
    "acceptance": "MOTION_RUNTIME_PLAYBACK_AND_RIG_COMPATIBILITY_NOT_YET_PROVEN",
}
out = Path("reports/c3-motion-conversion-audit.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("C3_MOTION_CONVERSION_AUDIT", json.dumps({
    key: report[key] for key in (
        "unique_motion_path_count", "source_motion_path_available_count",
        "source_motion_path_missing_count", "motion_path_converted_count",
        "motion_path_missing_conversion_count", "converted_without_motion_chunk_count",
        "status",
    )
}, ensure_ascii=False))
