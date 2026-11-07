#!/usr/bin/env python3
"""Build an evidence-only inventory of original C3 body models for all 11 game classes."""
import json
from pathlib import Path

ROOT = Path.cwd()
REPORTS = ROOT / "reports"
ROLE = ROOT / "resource_stage/world/resource_mappings/role_model_candidate_catalog.json"
AUDIT = REPORTS / "c3-model-audit.json"
MESH_CATALOG = ROOT / "resource_stage/world/resource_mappings/mesh_equipment_catalog.json"
OUT = REPORTS / "eleven-class-body-candidate-inventory.json"
CLASSES = [
    "Trojan", "Warrior", "Archer", "Ninja", "Monk", "Pirate",
    "Dragon Warrior", "Windwalker", "Thunderstriker", "Water Taoist", "Fire Taoist",
]


def unique_records(records):
    unique = {}
    for record in records:
        key = (record["gender"], record["slot"], record["profession_index"], record["simple_object_id"])
        unique[key] = record
    return list(unique.values())


def main():
    roles = json.loads(ROLE.read_text(encoding="utf-8"))
    audit = json.loads(AUDIT.read_text(encoding="utf-8"))
    mesh_catalog = json.loads(MESH_CATALOG.read_text(encoding="utf-8"))

    bodies = {}
    for row in audit.get("converted", []):
        src = row.get("source", "")
        if "/c3/body/" not in src or not src.endswith(".c3"):
            continue
        model = Path(src).stem
        item = bodies.setdefault(model, {
            "model_id": model,
            "source_c3": src,
            "glb_output": row.get("output"),
            "texture_source": row.get("texture"),
            "mesh_count": row.get("mesh_count"),
            "animated_mesh_count": row.get("animated_mesh_count"),
            "source_rows": 0,
        })
        item["source_rows"] += 1

    # Exact body-file-to-armor.dbc part-path join. This proves source usage,
    # not class identity or final visual correctness.
    armor_records = mesh_catalog.get("tables", {}).get("ini/armor.dbc", {}).get("records", [])
    for model, item in bodies.items():
        expected = f"c3/body/{model}.c3".lower()
        matches = []
        for record in armor_records:
            for part in record.get("parts", []):
                mesh_path = str(part.get("mesh_path") or "").replace("\\", "/").lower().lstrip("/")
                if mesh_path == expected or mesh_path.endswith("/" + expected):
                    matches.append({
                        "armor_record_id": record.get("unique_id"),
                        "part_index": part.get("part_index"),
                        "mesh_id": part.get("mesh_id"),
                        "mesh_path": part.get("mesh_path"),
                        "texture_id": part.get("texture_id"),
                        "texture_path": part.get("texture_path"),
                        "mesh_path_resolved": part.get("mesh_path_resolved"),
                        "texture_path_resolved": part.get("texture_path_resolved"),
                    })
        item["armor_db_mesh_reference_count"] = len(matches)
        item["armor_db_record_ids"] = sorted({x["armor_record_id"] for x in matches if x["armor_record_id"] is not None})
        item["armor_db_texture_paths"] = sorted({x["texture_path"] for x in matches if x["texture_path"]})[:30]
        item["armor_db_mesh_reference_samples"] = matches[:30]
        item["armor_db_usage_status"] = (
            "REFERENCED_BY_ARMOR_DBC_WITH_SOURCE_TEXTURE_PATHS"
            if matches else "NO_ARMOR_DBC_PART_PATH_REFERENCE_FOUND"
        )

    identity = {}
    for row in roles.get("selection_ui_roles_unjoined", []):
        src = row.get("source_role_identity") or {}
        token = src.get("class_token")
        if token:
            identity.setdefault(token, []).append({
                "gender": src.get("gender"),
                "slot": row.get("slot"),
                "profession_index": row.get("profession_index"),
                "simple_object_id": (row.get("simple_role_join") or {}).get("simple_object_id"),
                "evidence_source": "rolechoose.ini",
                "identity_status": src.get("identity_status"),
            })
    for row in roles.get("rolechoose_js_source_role_joins", []):
        src = row.get("source_identity") or {}
        token = src.get("class_token")
        if token:
            identity.setdefault(token, []).append({
                "gender": src.get("gender"),
                "slot": row.get("slot"),
                "profession_index": row.get("profession_index"),
                "simple_object_id": (row.get("simple_role_join") or {}).get("simple_object_id"),
                "evidence_source": "rolechoose_js.ini",
                "identity_status": row.get("mapping_status"),
            })

    # Character-selection labels are a separate evidence layer from the
    # rolechoose simple-object joins. Preserve all 18 UI slots and language
    # variants; they identify selectable classes but do not identify a body mesh.
    selection_labels = []
    for source in roles.get("additional_ui_registry_sources", []):
        if source.get("parse_status") != "PARSED":
            continue
        sections = source.get("sections", {})
        panel = sections.get("affirmPanel", {})
        for key, value in panel.items():
            match = __import__("re").fullmatch(r"vocation(\\d+)", str(key), __import__("re").I)
            if not match:
                continue
            label = str(value).strip()
            low = label.lower().replace("_", " ").replace("-", " ")
            gender = "female" if any(x in low for x in ("female", "woman", "hembra", "femen", "أنثى", "انثى", "قرصانة")) else (
                "male" if any(x in low for x in ("male", "man ", "macho", "mascul", "ذكر")) else None
            )
            if "taoist" in low or "حاوى" in low or "تاوي" in low:
                token = "Taoist"
            elif "trojan" in low or "تروجان" in low or "تروجان" in low:
                token = "Trojan"
            elif "archer" in low or "رام" in low or "arqu" in low:
                token = "Archer"
            elif "warrior" in low or "محارب" in low or "guerrer" in low:
                token = "Warrior"
            elif "ninja" in low or "نينجا" in low:
                token = "Ninja"
            elif "monk" in low or "راهب" in low or "monje" in low:
                token = "Monk"
            elif "saint" in low or "قديس" in low or "monja" in low:
                token = "Saint"
            elif "pirate" in low or "قرصان" in low or "pirata" in low:
                token = "Pirate"
            elif "dragon" in low or "التنين" in low or "dragón" in low:
                token = "Dragon Warrior"
            elif "windwalker" in low or "راكب" in low or "genio de aire" in low:
                token = "Windwalker"
            else:
                token = None
            selection_labels.append({
                "source_file": source.get("path"),
                "source_section": "affirmPanel",
                "slot": int(match.group(1)),
                "source_label": label,
                "normalized_source_token": token,
                "gender": gender,
                "evidence_status": "SOURCE_CHARACTER_SELECTION_LABEL_ONLY",
            })

    matrix = []
    for name in CLASSES:
        records = unique_records(identity.get(name, []))
        joined = [r for r in records if r["simple_object_id"] is not None]
        selection = [r for r in selection_labels if r["normalized_source_token"] == name]
        if joined:
            status = "SOURCE_CLASS_GENDER_AND_SIMPLE_ROLE_JOIN_FOUND_BODY_ASSET_UNRESOLVED"
        elif records:
            status = "SOURCE_ROLE_LABEL_FOUND_SIMPLE_ROLE_JOIN_UNRESOLVED"
        else:
            status = "NO_DIRECT_SOURCE_IDENTITY_EVIDENCE_FOUND"
        matrix.append({
            "game_class": name,
            "source_identity_tokens": [name] if records else [],
            "source_identity_records": records,
            "simple_role_join_records": joined,
            "character_selection_label_records": selection,
            "body_model_candidates": [],
            "status": status if records or not selection else "CHARACTER_SELECTION_LABEL_FOUND_BODY_AND_SIMPLE_ROLE_JOIN_UNRESOLVED",
        })

    unresolved_tokens = []
    for token in sorted((set(identity) | {r["normalized_source_token"] for r in selection_labels if r["normalized_source_token"]}) - set(CLASSES)):
        records = unique_records(identity[token])
        unresolved_tokens.append({
            "source_identity_token": token,
            "source_identity_records": records,
            "simple_role_join_records": [r for r in records if r["simple_object_id"] is not None],
            "normalization_status": "SOURCE_TOKEN_NOT_NORMALIZED_TO_A_GAME_CLASS",
        })

    referenced = sum(bool(x["armor_db_mesh_reference_count"]) for x in bodies.values())
    result = {
        "schema_version": "1.4.0",
        "character_selection_slot_count": len(selection_labels),
        "character_selection_normalized_tokens": sorted({r["normalized_source_token"] for r in selection_labels if r["normalized_source_token"]}),
        "character_selection_slots_by_token": {
            token: [r for r in selection_labels if r["normalized_source_token"] == token]
            for token in sorted({r["normalized_source_token"] for r in selection_labels if r["normalized_source_token"]})
        },
        "source": "Conquer Online Mobile 1.1.2.3 C3 conversion audit + WDB armor.dbc",
        "converted_unique_body_models": len(bodies),
        "armor_db_record_count": len(armor_records),
        "body_candidates_with_armor_db_mesh_references": referenced,
        "body_candidates_without_armor_db_mesh_references": len(bodies) - referenced,
        "source_identity_token_count": len(identity),
        "game_classes_with_source_label_match": sum(bool(x["source_identity_records"]) for x in matrix),
        "game_classes_with_simple_role_index_joins": sum(bool(x["simple_role_join_records"]) for x in matrix),
        "unresolved_source_identity_tokens": unresolved_tokens,
        "body_model_candidates": sorted(bodies.values(), key=lambda x: x["model_id"]),
        "class_matrix": matrix,
        "normalization_notes": {
            "Taoist": "A generic Taoist source token and Role0/Role1 simple-role joins exist, but the source evidence does not split them into Water Taoist and Fire Taoist.",
            "Dragon Warrior": "No direct source token found; do not infer from generic Warrior.",
            "Ninja": "Source role labels exist, but no matching simple-role records were joined.",
            "Monk": "A source role label exists, but no matching simple-role record was joined.",
            "Pirate": "Source role labels exist, but no matching simple-role records were joined.",
        },
        "policy": (
            "Armor.dbc part-path references prove that a C3 body source is used by one or more armor records; "
            "they do not prove a character-selection class/gender mapping. All body models remain unassigned. "
            "Approval requires an exact source identity join, compatible texture, rig/motion validation, "
            "and visual/runtime review."
        ),
    }
    REPORTS.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "converted_unique_body_models": len(bodies),
        "armor_db_record_count": len(armor_records),
        "body_candidates_with_armor_db_mesh_references": referenced,
        "body_candidates_without_armor_db_mesh_references": len(bodies) - referenced,
        "source_identity_tokens": len(identity),
        "game_classes_with_source_labels": result["game_classes_with_source_label_match"],
        "game_classes_with_simple_role_joins": result["game_classes_with_simple_role_index_joins"],
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
