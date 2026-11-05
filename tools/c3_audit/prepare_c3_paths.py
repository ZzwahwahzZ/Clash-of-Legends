#!/usr/bin/env python3
import csv, json
from pathlib import Path

source = Path("resource-source-index.csv")
catalog_path = Path("resource_stage/world/resource_mappings/mesh_equipment_catalog.json")
if not source.is_file():
    raise SystemExit("resource-source-index.csv is missing.")
catalog_available = catalog_path.is_file()

c3_paths = set()
pvr_paths = set()
source_by_inner = {}
resource_stage_rehydrated = Path("resource_stage").is_dir()

def staged_path_available(path):
    return (not resource_stage_rehydrated) or Path(path).is_file()

with source.open("r", encoding="utf-8-sig", newline="") as stream:
    for row in csv.DictReader(stream):
        category = row.get("category", "")
        source_path = row.get("source_path", "")
        staged = row.get("staged_path", "")
        if any(ord(char) < 32 or ord(char) == 127 for char in source_path):
            continue
        if ".." in Path(staged).parts:
            continue
        inner = source_path.split("!")[-1].replace("\\", "/").lower()
        if inner:
            source_by_inner.setdefault(inner, []).append(row)
        if category == "models" and inner.endswith(".c3") and staged.startswith("resource_stage/models/") and staged_path_available(staged):
            c3_paths.add(staged)
        if category == "models" and inner.endswith(".pvr") and inner.startswith("c3/") and staged.startswith("resource_stage/models/") and Path(staged).is_file():
            pvr_paths.add(staged)

catalog = json.loads(catalog_path.read_text(encoding="utf-8")) if catalog_available else {"tables": {}}
family_coverage = {}
missing_samples = []
referenced_mesh_paths = set()
referenced_texture_paths = set()
for table_name, table in catalog.get("tables", {}).items():
    family = table_name.rsplit("/", 1)[-1]
    mesh_found = texture_found = mix_texture_found = 0
    mesh_missing = texture_missing = mix_texture_missing = 0
    for record in table.get("records", []):
        for part in record.get("parts", []):
            mesh_path = str(part.get("mesh_path") or "").replace("\\", "/").lower()
            texture_path = str(part.get("texture_path") or "").replace("\\", "/").lower()
            mix_texture_path = str(part.get("mix_texture_path") or "").replace("\\", "/").lower()
            if mesh_path:
                referenced_mesh_paths.add(mesh_path)
                rows = source_by_inner.get(mesh_path, [])
                staged_files = [row.get("staged_path", "") for row in rows if row.get("staged_path")]
                present = next((path for path in staged_files if staged_path_available(path)), None)
                if present:
                    c3_paths.add(present)
                    mesh_found += 1
                else:
                    mesh_missing += 1
                    if len(missing_samples) < 250:
                        missing_samples.append({"family": family, "kind": "mesh", "path": mesh_path, "unique_id": record.get("unique_id")})
            if texture_path:
                referenced_texture_paths.add(texture_path)
                rows = source_by_inner.get(texture_path, [])
                staged_files = [row.get("staged_path", "") for row in rows if row.get("staged_path")]
                present = next((path for path in staged_files if Path(path).is_file()), None)
                if present:
                    pvr_paths.add(present)
                    texture_found += 1
                else:
                    texture_missing += 1
                    if len(missing_samples) < 250:
                        missing_samples.append({"family": family, "kind": "texture", "path": texture_path, "unique_id": record.get("unique_id")})
            if mix_texture_path:
                referenced_texture_paths.add(mix_texture_path)
                rows = source_by_inner.get(mix_texture_path, [])
                staged_files = [row.get("staged_path", "") for row in rows if row.get("staged_path")]
                present = next((path for path in staged_files if Path(path).is_file()), None)
                if present:
                    pvr_paths.add(present)
                    mix_texture_found += 1
                else:
                    mix_texture_missing += 1
                    if len(missing_samples) < 250:
                        missing_samples.append({"family": family, "kind": "mix_texture", "path": mix_texture_path, "unique_id": record.get("unique_id")})
    family_coverage[family] = {
        "record_count": table.get("record_count", 0),
        "mesh_path_file_found_count": mesh_found,
        "mesh_path_missing_count": mesh_missing,
        "texture_path_file_found_count": texture_found,
        "texture_path_missing_count": texture_missing,
        "mix_texture_path_file_found_count": mix_texture_found,
        "mix_texture_path_missing_count": mix_texture_missing,
    }

motion_catalog_path = Path("resource_stage/world/resource_mappings/motion_catalog.json")
motion_paths_added = 0
motion_paths_missing = 0
if motion_catalog_path.is_file():
    motion_catalog = json.loads(motion_catalog_path.read_text(encoding="utf-8"))
    for motion_path in motion_catalog.get("unique_motion_paths", []):
        normalized = str(motion_path).replace("\\", "/").lower()
        rows = source_by_inner.get(normalized, [])
        staged_files = [row.get("staged_path", "") for row in rows if row.get("staged_path")]
        present = next((path for path in staged_files if staged_path_available(path)), None)
        if present:
            c3_paths.add(present)
            motion_paths_added += 1
        else:
            motion_paths_missing += 1
            if len(missing_samples) < 250:
                missing_samples.append({"family": "motion_tables", "kind": "motion", "path": normalized})

if not c3_paths:
    raise SystemExit("No clean original C3 model paths were found.")
if not pvr_paths:
    raise SystemExit("No C3-related PVR texture paths were found.")

Path("build").mkdir(parents=True, exist_ok=True)
Path("build/c3-paths.json").write_text(json.dumps(sorted(c3_paths), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
Path("build/pvr-paths.json").write_text(json.dumps(sorted(pvr_paths), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
coverage = {
    "schema_version": "1.0.0",
    "source_index": str(source),
    "mesh_equipment_catalog": str(catalog_path) if catalog_available else None,
    "mesh_catalog_available": catalog_available,
    "unique_mesh_path_reference_count": len(referenced_mesh_paths),
    "unique_texture_path_reference_count": len(referenced_texture_paths),
    "final_c3_path_count": len(c3_paths),
    "final_pvr_path_count": len(pvr_paths),
    "motion_catalog_available": motion_catalog_path.is_file(),
    "motion_path_added_count": motion_paths_added,
    "motion_path_missing_count": motion_paths_missing,
    "family_coverage": family_coverage,
    "missing_reference_samples": missing_samples,
    "status": "SOURCE_PATHS_EXPANDED_FROM_MESH_TABLES_REQUIRES_CONVERSION_AND_VISUAL_REVIEW" if catalog_available else "SOURCE_INDEX_ONLY_MESH_CATALOG_NOT_AVAILABLE",
    "note": "Only paths found as actual staged files are added. Missing paths remain reported and are never fabricated."
}
Path("reports").mkdir(exist_ok=True)
Path("reports/c3-equipment-source-path-coverage.json").write_text(json.dumps(coverage, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Prepared {len(c3_paths)} C3 model paths and {len(pvr_paths)} C3 PVR texture paths from source index plus MESH references.")
for family, values in family_coverage.items():
    print(f"{family}: C3 present={values['mesh_path_file_found_count']} missing={values['mesh_path_missing_count']} | PVR present={values['texture_path_file_found_count']} missing={values['texture_path_missing_count']} | blend PVR present={values['mix_texture_path_file_found_count']} missing={values['mix_texture_path_missing_count']}")
