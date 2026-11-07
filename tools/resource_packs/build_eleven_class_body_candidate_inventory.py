#!/usr/bin/env python3
"""Build an evidence-only inventory of original C3 body models for all 11 game classes."""
import json
from pathlib import Path

ROOT = Path.cwd()
REPORTS = ROOT / "reports"
ROLE = ROOT / "resource_stage/world/resource_mappings/role_model_candidate_catalog.json"
AUDIT = REPORTS / "c3-model-audit.json"
OUT = REPORTS / "eleven-class-body-candidate-inventory.json"
CLASSES = [
    "Trojan", "Warrior", "Archer", "Ninja", "Monk", "Pirate",
    "Dragon Warrior", "Windwalker", "Thunderstriker", "Water Taoist", "Fire Taoist",
]


def main():
    roles = json.loads(ROLE.read_text(encoding="utf-8"))
    audit = json.loads(AUDIT.read_text(encoding="utf-8"))

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

    def unique_records(records):
        unique = {}
        for record in records:
            key = (record["gender"], record["slot"], record["profession_index"], record["simple_object_id"])
            unique[key] = record
        return list(unique.values())

    matrix = []
    for name in CLASSES:
        records = unique_records(identity.get(name, []))
        joined = [r for r in records if r["simple_object_id"] is not None]
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
            "body_model_candidates": [],
            "status": status,
        })

    unresolved_tokens = []
    for token in sorted(set(identity) - set(CLASSES)):
        records = unique_records(identity[token])
        unresolved_tokens.append({
            "source_identity_token": token,
            "source_identity_records": records,
            "simple_role_join_records": [r for r in records if r["simple_object_id"] is not None],
            "normalization_status": "SOURCE_TOKEN_NOT_NORMALIZED_TO_A_GAME_CLASS",
        })

    result = {
        "schema_version": "1.2.0",
        "source": "Conquer Online Mobile 1.1.2.3 C3 conversion audit",
        "converted_unique_body_models": len(bodies),
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
            "All body models remain an unassigned candidate pool. Source labels and simple-role "
            "index joins are evidence only, not approved body-model mappings. No class assignment "
            "is approved by numeric similarity, filename order, or visual guess. Approval requires "
            "an exact source asset join, resolved compatible texture, rig/motion validation, and "
            "visual/runtime review."
        ),
    }
    REPORTS.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "converted_unique_body_models": len(bodies),
        "game_classes": len(CLASSES),
        "source_identity_tokens": len(identity),
        "game_classes_with_source_labels": result["game_classes_with_source_label_match"],
        "game_classes_with_simple_role_joins": result["game_classes_with_simple_role_index_joins"],
        "unresolved_source_tokens": len(unresolved_tokens),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
