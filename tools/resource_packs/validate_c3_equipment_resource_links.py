#!/usr/bin/env python3
"""Validate source-linked C3 equipment mesh/texture paths against extracted Mobile TPI assets."""
import csv, json
from pathlib import Path

catalog_path = Path("resource_stage/world/resource_mappings/mesh_equipment_catalog.json")
index_path = Path("reports/resource-source-index.csv")
if not catalog_path.is_file() or not index_path.is_file():
    raise SystemExit("Missing MESH catalog or resource source index")

catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
source_paths = {}
with index_path.open("r", encoding="utf-8-sig", newline="") as stream:
    for row in csv.DictReader(stream):
        source = row.get("source_path", "").replace("\\", "/")
        low = source.lower()
        marker = "!c3/"
        if marker in low:
            tail = source[low.index(marker) + len(marker):]
            normalized = ("c3/" + tail).lower()
            source_paths.setdefault(normalized, []).append({
                "source_path": source, "staged_path": row.get("staged_path", "")
            })

summary = {}
all_missing_mesh = []
all_missing_texture = []
for table_name, table in catalog.get("tables", {}).items():
    mesh_refs = texture_refs = mix_texture_refs = mesh_found = texture_found = mix_texture_found = fully_found = 0
    motion_refs = motion_found = 0
    missing_mesh = []
    missing_texture = []
    missing_mix_texture = []
    missing_motion = []
    unique_mesh_paths = set()
    unique_texture_paths = set()
    unique_mix_texture_paths = set()
    found_mesh_paths = set()
    found_texture_paths = set()
    found_mix_texture_paths = set()
    for record in table.get("records", []):
        for part in record.get("parts", []):
            mesh_path = str(part.get("mesh_path") or "").replace("\\", "/").lower()
            texture_path = str(part.get("texture_path") or "").replace("\\", "/").lower()
            mix_texture_path = str(part.get("mix_texture_path") or "").replace("\\", "/").lower()
            mesh_refs += bool(mesh_path)
            texture_refs += bool(texture_path)
            mix_texture_refs += bool(mix_texture_path)
            if mesh_path:
                unique_mesh_paths.add(mesh_path)
            if texture_path:
                unique_texture_paths.add(texture_path)
            if mix_texture_path:
                unique_mix_texture_paths.add(mix_texture_path)
            mesh_rows = source_paths.get(mesh_path, [])
            texture_rows = source_paths.get(texture_path, [])
            mix_texture_rows = source_paths.get(mix_texture_path, []) if mix_texture_path else []
            mesh_exists = any(row["staged_path"] and Path(row["staged_path"]).is_file() for row in mesh_rows)
            texture_exists = any(row["staged_path"] and Path(row["staged_path"]).is_file() for row in texture_rows)
            mix_texture_exists = (not mix_texture_path) or any(row["staged_path"] and Path(row["staged_path"]).is_file() for row in mix_texture_rows)
            mesh_found += mesh_exists
            texture_found += texture_exists
            mix_texture_found += bool(mix_texture_path and mix_texture_exists)
            if mesh_path and mesh_exists:
                found_mesh_paths.add(mesh_path)
            if texture_path and texture_exists:
                found_texture_paths.add(texture_path)
            if mix_texture_path and mix_texture_exists:
                found_mix_texture_paths.add(mix_texture_path)
            fully_found += mesh_exists and texture_exists and mix_texture_exists
            if mesh_path and not mesh_exists and len(missing_mesh) < 100:
                missing_mesh.append({"unique_id": record.get("unique_id"), "path": mesh_path, "source_index_matches": len(mesh_rows)})
            if texture_path and not texture_exists and len(missing_texture) < 100:
                missing_texture.append({"unique_id": record.get("unique_id"), "path": texture_path, "source_index_matches": len(texture_rows)})
            if mix_texture_path and not mix_texture_exists and len(missing_mix_texture) < 100:
                missing_mix_texture.append({"unique_id": record.get("unique_id"), "path": mix_texture_path, "source_index_matches": len(mix_texture_rows)})
        for motion in record.get("motion_records", []):
            motion_path = str(motion.get("motion_path") or "").replace("\\", "/").lower()
            if not motion_path:
                continue
            motion_refs += 1
            motion_rows = source_paths.get(motion_path, [])
            motion_exists = any(row["staged_path"] and Path(row["staged_path"]).is_file() for row in motion_rows)
            motion_found += motion_exists
            if not motion_exists and len(missing_motion) < 100:
                missing_motion.append({"unique_id": record.get("unique_id"), "motion_key": motion.get("motion_key"), "path": motion_path, "source_index_matches": len(motion_rows)})
    summary[table_name] = {
        "record_count": table.get("record_count", 0),
        "mesh_path_reference_count": mesh_refs,
        "mesh_file_found_count": mesh_found,
        "unique_mesh_path_count": len(unique_mesh_paths),
        "unique_mesh_path_file_found_count": len(found_mesh_paths),
        "unique_mesh_path_missing_count": len(unique_mesh_paths - found_mesh_paths),
        "texture_path_reference_count": texture_refs,
        "texture_file_found_count": texture_found,
        "unique_texture_path_count": len(unique_texture_paths),
        "unique_texture_path_file_found_count": len(found_texture_paths),
        "unique_texture_path_missing_count": len(unique_texture_paths - found_texture_paths),
        "mix_texture_path_reference_count": mix_texture_refs,
        "mix_texture_file_found_count": mix_texture_found,
        "unique_mix_texture_path_count": len(unique_mix_texture_paths),
        "unique_mix_texture_path_file_found_count": len(found_mix_texture_paths),
        "unique_mix_texture_path_missing_count": len(unique_mix_texture_paths - found_mix_texture_paths),
        "fully_present_part_count": fully_found,
        "motion_path_reference_count": motion_refs,
        "motion_file_found_count": motion_found,
        "missing_mesh_path_samples": missing_mesh,
        "missing_texture_path_samples": missing_texture,
        "missing_mix_texture_path_samples": missing_mix_texture,
        "missing_motion_path_samples": missing_motion,
        "status": "SOURCE_FILES_PRESENT_REQUIRES_VISUAL_REVIEW" if mesh_found and texture_found else "SOURCE_FILE_GAPS_REMAIN",
    }
    all_missing_mesh.extend(missing_mesh)
    all_missing_texture.extend(missing_texture)

report = {
    "schema_version": "1.0.0",
    "source_index": str(index_path),
    "mesh_catalog": str(catalog_path),
    "c3_path_index_count": len(source_paths),
    "family_audits": summary,
    "missing_mesh_path_sample_count": len(all_missing_mesh),
    "missing_texture_path_sample_count": len(all_missing_texture),
    "production_acceptance": "BLOCKED_NOT_APPROVED",
    "policy": "File presence proves only that a referenced path exists in the extracted source index; it does not prove mesh identity, texture binding, UV correctness, skeleton compatibility or visual quality."
}
out = Path("reports/c3-equipment-resource-link-audit.json")
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("C3_EQUIPMENT_RESOURCE_LINK_AUDIT", json.dumps({
    key: {
        "records": value["record_count"],
        "mesh_found": value["mesh_file_found_count"],
        "mesh_unique": f"{value['unique_mesh_path_file_found_count']}/{value['unique_mesh_path_count']}",
        "texture_found": value["texture_file_found_count"],
        "texture_unique": f"{value['unique_texture_path_file_found_count']}/{value['unique_texture_path_count']}",
        "mix_texture_found": value["mix_texture_file_found_count"],
        "motion_found": value["motion_file_found_count"],
        "status": value["status"],
    }
    for key, value in summary.items()
}, ensure_ascii=False))
