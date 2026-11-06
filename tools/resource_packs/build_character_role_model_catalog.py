#!/usr/bin/env python3
"""Build source-backed, non-approved Mobile role -> simple-object -> C3 candidates."""
from __future__ import annotations

import configparser
import hashlib
import json
from pathlib import Path

ROOT = Path.cwd()
RESOURCE = ROOT / "resource_stage"
MAPPING_DIR = RESOURCE / "world/resource_mappings"
MESH_CATALOG = MAPPING_DIR / "mesh_equipment_catalog.json"
MOTION_CATALOG = MAPPING_DIR / "motion_catalog.json"


def find_source(name: str) -> Path:
    matches = list(RESOURCE.rglob(name))
    if len(matches) != 1:
        raise SystemExit(f"Expected exactly one extracted {name}, found {len(matches)}")
    return matches[0]


def parse_ini(path: Path) -> dict[str, dict[str, str]]:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    raw = path.read_bytes()
    text = None
    for encoding in ("utf-8-sig", "gb18030", "cp1252"):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            pass
    if text is None:
        text = raw.decode("utf-8", errors="replace")
    parser.read_string(text)
    return {section: dict(parser.items(section)) for section in parser.sections()}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    simple_role_path = find_source("3dsimplerole.ini")
    role_choose_path = find_source("rolechoose.ini")
    mesh_catalog = json.loads(MESH_CATALOG.read_text(encoding="utf-8"))
    motion_catalog = json.loads(MOTION_CATALOG.read_text(encoding="utf-8"))

    simple_by_id = {
        int(row["simple_object_id"]): row
        for row in mesh_catalog.get("simple_objects", [])
    }
    motion_by_id: dict[int, list[dict]] = {}
    for table_name, table in motion_catalog.get("tables", {}).items():
        for row in table.get("records", []):
            motion_by_id.setdefault(int(row["motion_id"]), []).append({
                "table": table_name,
                "path": row.get("motion_path", ""),
            })

    simple_sections = parse_ini(simple_role_path)
    role_rows = []
    for section_name, fields in simple_sections.items():
        if "3DSimpleObjID" not in fields:
            continue
        try:
            simple_id = int(fields["3DSimpleObjID"])
            standby_id = int(fields.get("3DStandByMotion", "0"))
            blaze_id = int(fields.get("3DBlazeMotion", "0"))
        except ValueError:
            continue
        simple = simple_by_id.get(simple_id)
        role_rows.append({
            "source_section": section_name,
            "simple_object_id": simple_id,
            "simple_object_found": simple is not None,
            "simple_object": simple,
            "standby_motion_id": standby_id,
            "standby_motion_paths": motion_by_id.get(standby_id, []),
            "blaze_motion_id": blaze_id,
            "blaze_motion_paths": motion_by_id.get(blaze_id, []),
            "blaze_sound": fields.get("BlazeSound", ""),
            "selection_effect_front": fields.get("F3DEffect", ""),
            "selection_effect_back": fields.get("B3DEffect", ""),
            "mapping_status": "SOURCE_JOIN_CANDIDATE_ONLY_NOT_CLASS_OR_GENDER_APPROVED",
        })

    choose_sections = parse_ini(role_choose_path)
    choose = choose_sections.get("proAni", {})
    indices = choose_sections.get("proIndex", {})
    selection_rows = []
    for key, animation_role in sorted(choose.items()):
        slot = key.removeprefix("pro_")
        index_key = "index_" + slot
        selection_rows.append({
            "slot": int(slot) if slot.isdigit() else slot,
            "animation_role": animation_role,
            "profession_index": indices.get(index_key, ""),
            "simple_role_join": None,
            "mapping_status": "UI_ROLE_TO_SIMPLE_ROLE_JOIN_NOT_ESTABLISHED",
        })

    output = {
        "schema_version": "1.0.0",
        "source_client": "Conquer Online Mobile 1.1.2.3",
        "source_files": {
            "3dsimplerole_ini": str(simple_role_path.relative_to(ROOT)),
            "3dsimplerole_sha256": digest(simple_role_path),
            "rolechoose_ini": str(role_choose_path.relative_to(ROOT)),
            "rolechoose_sha256": digest(role_choose_path),
            "mesh_equipment_catalog": str(MESH_CATALOG.relative_to(ROOT)),
            "motion_catalog": str(MOTION_CATALOG.relative_to(ROOT)),
        },
        "role_simple_object_candidates": role_rows,
        "selection_ui_roles_unjoined": selection_rows,
        "rolepart": mesh_catalog.get("role_parts", {}),
        "summary": {
            "simple_role_records": len(role_rows),
            "simple_object_ids_found": sum(1 for row in role_rows if row["simple_object_found"]),
            "standby_motion_ids_found": sum(1 for row in role_rows if row["standby_motion_paths"]),
            "blaze_motion_ids_found": sum(1 for row in role_rows if row["blaze_motion_paths"]),
            "selection_ui_slots": len(selection_rows),
            "class_gender_mappings_approved": 0,
        },
        "policy": "All rows are source-backed joins or explicit unresolved UI slots. No class/gender mapping is approved without a direct source key and visual/rig validation.",
    }
    MAPPING_DIR.mkdir(parents=True, exist_ok=True)
    out = MAPPING_DIR / "role_model_candidate_catalog.json"
    out.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
