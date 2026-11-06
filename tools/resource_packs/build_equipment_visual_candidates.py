#!/usr/bin/env python3
"""Promote only exact source-joined C3 weapon meshes into the runtime visual catalog.

A promoted entry is a mapped static weapon candidate, not proof of class compatibility,
hand-socket alignment, animation, or final visual acceptance.
"""
import json
from pathlib import Path

ROOT = Path.cwd()
JOIN = ROOT / "resource_stage/world/resource_mappings/equipment_item_join_catalog.json"
RESOURCE = ROOT / "resource_stage/world/resource_catalog.json"
OUTPUT = ROOT / "resource_stage/world/resource_mappings/equipment_visual_catalog.json"
REPORT = ROOT / "reports/equipment-visual-candidate-audit.json"

if not JOIN.is_file() or not RESOURCE.is_file():
    raise SystemExit("Required source join or runtime resource catalog is missing.")

join = json.loads(JOIN.read_text(encoding="utf-8"))
catalog = json.loads(RESOURCE.read_text(encoding="utf-8"))
equipment_entries = catalog.get("assets", {}).get("equipment", [])
by_path = {str(row.get("path", "")): row for row in equipment_entries if isinstance(row, dict)}

grouped = {}
for row in join.get("weapon_items", {}).get("records", []):
    item_id = str(row.get("item_or_model_id", "")).strip()
    if not item_id:
        continue
    for part in row.get("mesh_parts", []):
        mesh_path = str(part.get("mesh_path") or "").replace("\\", "/").lower()
        prefix = "c3/weapon/"
        if not mesh_path.startswith(prefix) or not mesh_path.endswith(".c3"):
            continue
        model_id = Path(mesh_path).stem
        staged_path = f"resource_stage/equipment/converted_c3/c3/weapon/{model_id}.glb"
        entry = by_path.get(staged_path)
        if entry is None or not (ROOT / staged_path).is_file():
            continue
        grouped.setdefault(staged_path, set()).add(item_id)

records = []
for staged_path, item_ids in sorted(grouped.items()):
    entry = by_path[staged_path]
    entry["asset_role"] = "weapon_visual_candidate"
    entry["mapping_status"] = "source_join_verified"
    entry["source_item_ids"] = sorted(item_ids)
    records.append({
        "item_ids": sorted(item_ids),
        "model_path": staged_path,
        "source_mesh_path": "c3/weapon/" + Path(staged_path).stem + ".c3",
        "mapping_status": "source_join_verified",
        "attachment_status": "hand_socket_fit_pending",
        "animation_status": "static_equipment_mesh",
        "source_identity": "joined through Mobile weapon translation and MESH part path",
    })

if not records:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": "1.0.0",
        "policy": "No weapon candidates are promoted until the corresponding converted C3 weapon assets are staged and source-joined.",
        "candidate_model_count": 0,
        "mapped_item_id_count": 0,
        "records": [],
        "status": "DEFERRED_NO_STAGED_C3_WEAPON_ASSETS"
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\\n", encoding="utf-8")
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({"candidate_model_count": 0, "mapped_item_id_count": 0, "models": [], "runtime_role": "weapon_visual_candidate", "attachment_gate": "PENDING_STAGED_C3_WEAPON_ASSETS"}, ensure_ascii=False, indent=2) + "\\n", encoding="utf-8")
    print("EQUIPMENT_VISUAL_CANDIDATES deferred: no C3 weapon GLBs in the current skeletal proof subset.")
    raise SystemExit(0)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
payload = {
    "schema_version": "1.0.0",
    "policy": "Only exact Mobile item-to-MESH weapon path joins are exposed to runtime lookup. Hand socket fit remains a separate gate.",
    "candidate_model_count": len(records),
    "mapped_item_id_count": len({item for row in records for item in row["item_ids"]}),
    "records": records,
}
OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps({
    "candidate_model_count": len(records),
    "mapped_item_id_count": payload["mapped_item_id_count"],
    "models": records,
    "runtime_role": "weapon_visual_candidate",
    "attachment_gate": "PENDING_IN_GAME_HAND_SOCKET_REVIEW",
}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("EQUIPMENT_VISUAL_CANDIDATES", json.dumps({
    "models": len(records),
    "mapped_item_ids": payload["mapped_item_id_count"],
    "attachment_gate": "PENDING_IN_GAME_HAND_SOCKET_REVIEW",
}, ensure_ascii=False))
