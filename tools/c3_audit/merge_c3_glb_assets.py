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
# Deduplicate within a category, not globally: an identical mesh may be
# legitimately referenced by more than one gameplay category, and skipping it
# globally can silently leave (for example) the monsters PCK without any model.
existing_hashes = {
    (category, row.get("sha256"))
    for category, rows in assets.items() if isinstance(rows, list)
    for row in rows if isinstance(row, dict)
}
added = []
converted_category_counts = {}
for source in sorted(source_root.rglob("*.glb")):
    relative = source.relative_to(source_root)
    if len(relative.parts) < 2:
        continue
    category = relative.parts[0]
    if category not in {"characters", "monsters", "equipment", "mounts", "effects", "world"}:
        continue
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if (category, digest) in existing_hashes:
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
        # Conversion and import do not prove character/mount identity or visual approval.
        "asset_role": "unclassified",
        "mapping_status": "unreviewed",
    }
    assets.setdefault(category, []).append(entry)
    existing_hashes.add((category, digest))
    converted_category_counts[category] = converted_category_counts.get(category, 0) + 1
    added.append({"category": category, "path": entry["path"], "size_bytes": entry["size_bytes"], "kind": "converted_c3_glb"})
def register_additional_file(category: str, source: Path, destination: Path, source_label: str, asset_role: str, mapping_status: str) -> dict:
    if not source.is_file():
        raise SystemExit(f"Required C3 VAT runtime source is missing: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    entry = {
        "path": destination.relative_to(root).as_posix(),
        "source": source_label,
        "extension": destination.suffix.lower(),
        "size_bytes": destination.stat().st_size,
        "sha256": digest,
        "asset_role": asset_role,
        "mapping_status": mapping_status,
    }
    assets.setdefault(category, []).append(entry)
    added.append({"category": category, "path": entry["path"], "size_bytes": entry["size_bytes"]})
    return entry


# The six C3 full-character clips have passed source-vertex, VAT, and Godot
# import/visual checks. Stage their model bases and all position/normal textures
# together so the runtime controller can switch idle/walk/run without downloads.
character_vat_clips = {}
for model_id, look, gender in ((7130000, 7, "male"), (8133010, 8, "female")):
    base_clip_id = f"look{look}_model{model_id}_weapon500_action100"
    base_source = source_root / "motion-poc" / f"{base_clip_id}.glb"
    base_destination = stage_root / "animations" / "c3_character_vat_models" / f"{model_id}.glb"
    base_entry = register_additional_file(
        "animations", base_source, base_destination,
        f"Validated C3 full-character VAT base: {base_clip_id}",
        "c3_vat_character_base", "godot_validated_six_clip_runtime_candidate"
    )
    state_rows = {}
    for action, state in ((100, "idle"), (110, "walk"), (120, "run")):
        clip_id = f"look{look}_model{model_id}_weapon500_action{action}"
        source_dir = source_root / "motion-poc-vat"
        metadata_sources = sorted(source_dir.glob(f"{clip_id}_*.json"))
        if not metadata_sources:
            raise SystemExit(f"No validated VAT metadata files for {clip_id}")
        metadata_paths = []
        mesh_names = []
        for metadata_source in metadata_sources:
            metadata = json.loads(metadata_source.read_text(encoding="utf-8"))
            if metadata.get("clip_id") != clip_id or metadata.get("format") != "C3_VAT_RGBA32F":
                raise SystemExit(f"Invalid VAT metadata for {metadata_source}")
            data_name = str(metadata.get("binary_file", ""))
            normal_name = str(metadata.get("normal_binary_file", ""))
            if not data_name or not normal_name:
                raise SystemExit(f"VAT position/normal file references are missing in {metadata_source}")
            data_source = source_dir / data_name
            normal_source = source_dir / normal_name
            clip_destination = stage_root / "animations" / "c3_character_vat" / clip_id
            metadata_destination = clip_destination / metadata_source.name
            data_destination = clip_destination / data_name
            normal_destination = clip_destination / normal_name
            register_additional_file(
                "animations", metadata_source, metadata_destination,
                f"C3 VAT metadata: {clip_id}/{metadata_source.name}",
                "c3_vat_metadata", "godot_validated_six_clip_runtime_candidate"
            )
            register_additional_file(
                "animations", data_source, data_destination,
                f"C3 VAT positions: {clip_id}/{data_name}",
                "c3_vat_position_texture", "godot_validated_six_clip_runtime_candidate"
            )
            register_additional_file(
                "animations", normal_source, normal_destination,
                f"C3 VAT animated normals: {clip_id}/{normal_name}",
                "c3_vat_normal_texture", "godot_validated_six_clip_runtime_candidate"
            )
            metadata_paths.append(metadata_destination.relative_to(root).as_posix())
            mesh_names.append(str(metadata.get("mesh_name", "")))
        state_rows[state] = {
            "clip_id": clip_id,
            "metadata_paths": metadata_paths,
            "mesh_names": mesh_names,
            "fps": 30,
            "status": "godot_validated_six_clip_runtime_candidate",
        }
    character_vat_clips[str(model_id)] = {
        "model_id": model_id,
        "look": look,
        "gender": gender,
        "base_model_path": base_entry["path"],
        "states": state_rows,
    }

catalog["character_vat_clips"] = character_vat_clips

# Keep the separately validated true-skeleton GLBs in the runtime character
# resource pack. They remain proof/catalog assets until class and gender
# identity mappings are independently approved.
skeleton_report_path = root / "reports/c3-motion-poc-validation.json"
if not skeleton_report_path.is_file():
    raise SystemExit("Missing Godot skeletal validation report.")
skeleton_report = json.loads(skeleton_report_path.read_text(encoding="utf-8"))
if skeleton_report.get("skeleton_catalog_status") != "PASSED":
    raise SystemExit("C3 skeleton catalog did not pass Godot validation.")
skeleton_rows = skeleton_report.get("skeleton_catalog", [])
expected_skeletons = int(skeleton_report.get("expected_skeleton_catalog_count", 0))
if expected_skeletons <= 0 or len(skeleton_rows) != expected_skeletons:
    raise SystemExit("C3 skeleton catalog report is incomplete.")
skeleton_catalog = []
for row in skeleton_rows:
    source = source_root / "skeleton-poc" / Path(str(row.get("path", "")).replace("\\\\", "/")).name
    if not source.is_file() or row.get("status") != "GODOT_SKELETON_CATALOG_VALIDATED":
        raise SystemExit(f"Missing or unvalidated C3 skeleton GLB: {source}")
    filename = source.name
    destination = stage_root / "characters" / "c3_skeleton_poc" / filename
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    entry = {
        "path": destination.relative_to(root).as_posix(),
        "source": "Godot-validated C3 skeletal catalog POC",
        "extension": ".glb",
        "size_bytes": destination.stat().st_size,
        "sha256": digest,
        "asset_role": "skeletal_character_poc",
        "mapping_status": "godot_skeleton_catalog_validated_identity_mapping_pending",
        "skeleton_count": int(row.get("skeleton_count", 0)),
        "bone_count": int(row.get("skeleton_bone_count", 0)),
        "skinned_mesh_count": int(row.get("skinned_mesh_count", 0)),
        "animation_track_count": int(row.get("animation_track_count", 0)),
        "animation_key_count": int(row.get("animation_key_count", 0))
    }
    assets.setdefault("characters", []).append(entry)
    skeleton_catalog.append(entry)

catalog["c3_skeleton_catalog"] = {
    "status": "GODOT_VALIDATED",
    "expected_count": expected_skeletons,
    "validated_count": len(skeleton_catalog),
    "assets": skeleton_catalog,
    "identity_mapping_status": "PENDING_CLASS_AND_GENDER_SOURCE_JOIN"
}

catalog["asset_counts"] = {key: len(value) for key, value in assets.items() if isinstance(value, list)}
catalog["catalog_version"] = int(catalog.get("catalog_version", 1)) + 1
catalog["c3_conversion"] = {
    "format": "glb",
    "source": "validated C3/PVR conversion",
    "models_added": len(added),
    "category_counts": {key: sum(1 for item in added if item["category"] == key) for key in sorted({item["category"] for item in added})},
    "converted_glb_category_counts": converted_category_counts,
}
catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
report = {
    "models_added": len(added),
    "category_counts": catalog["c3_conversion"]["category_counts"],
    "converted_glb_category_counts": converted_category_counts,
    "character_vat_models": len(character_vat_clips),
    "character_vat_clips": {model_id: {state: len(row["metadata_paths"]) for state, row in data["states"].items()} for model_id, data in character_vat_clips.items()},
    "models": added,
}
Path("reports").mkdir(exist_ok=True)
Path("reports/c3-runtime-integration.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"models_added": len(added), "category_counts": catalog["c3_conversion"]["category_counts"]}, ensure_ascii=False, indent=2))
if not added:
    raise SystemExit("No converted C3 models were merged into the runtime catalog.")
