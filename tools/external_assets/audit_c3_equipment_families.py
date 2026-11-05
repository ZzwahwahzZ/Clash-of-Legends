#!/usr/bin/env python3
"""Build an evidence-only family inventory from the original C3 conversion report.

Path names classify source folders only. They do not establish an item's identity,
slot, paid/free status, texture binding, rig fit, or production approval.
"""
from __future__ import annotations
import argparse, json
from collections import defaultdict, Counter
from pathlib import Path

FAMILIES = {
    "helmet_headgear": "armet",
    "hair_cosmetics": "hair",
    "head_components": "head",
    "weapons": "weapon",
    "body_armor": "armor",
    "mounts": "mount",
    "mount_accessories": "mount_accessory",
    "shields": "shield",
    "fashion_garments": "garment",
}

def family_for(source: str) -> str:
    parts = source.lower().replace("\\", "/").split("/")
    if "armet" in parts: return "helmet_headgear"
    if "hair" in parts: return "hair_cosmetics"
    if "head" in parts: return "head_components"
    if "weapon" in parts and "effect" not in parts and "weaponmotion" not in parts: return "weapons"
    if ("armor" in parts or "armour" in parts) and "effect" not in parts: return "body_armor"
    if ("mount" in parts or "ride" in parts) and "effect" not in parts: return "mounts"
    if "garment" in parts or "fashion" in parts: return "fashion_garments"
    if "shield" in parts: return "shields"
    return "unclassified"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("audit", type=Path, help="c3-model-audit.json")
    ap.add_argument("--project-root", type=Path, default=Path("."))
    ap.add_argument("--output", type=Path, default=Path("reports/equipment/c3-equipment-family-audit.json"))
    args = ap.parse_args()
    data = json.loads(args.audit.read_text(encoding="utf-8"))
    converted = data.get("converted", [])
    model_by_path = {m.get("path", "").lower(): m for m in data.get("models", [])}
    grouped = defaultdict(list)
    for row in converted:
        src = row.get("source", "")
        fam = family_for(src)
        if fam == "unclassified" and not row.get("output", "").startswith("equipment/"):
            continue
        model = model_by_path.get(src.lower(), {})
        texture = row.get("texture", "")
        texture_path = args.project_root / texture if texture else None
        mesh_details = model.get("meshes", [])
        extents = []
        texture_names = []
        for mesh in mesh_details:
            lo = mesh.get("bounds_minimum", [0, 0, 0])
            hi = mesh.get("bounds_maximum", [0, 0, 0])
            if len(lo) == 3 and len(hi) == 3:
                extents.append([round(float(hi[i]) - float(lo[i]), 6) for i in range(3)])
            if mesh.get("texture_name"):
                texture_names.append(mesh["texture_name"])
        max_extent_axes = sum(1 for axis in range(3) if any(e[axis] > 0.0001 for e in extents))
        triangles = int(model.get("triangle_count", 0))
        vertices = int(model.get("vertex_count", 0))
        geometry_ok = triangles >= 8 and vertices >= 12 and max_extent_axes >= 2
        grouped[fam].append({
            "source_c3": src,
            "source_model_id": Path(src).stem,
            "converted_glb": row.get("output", ""),
            "glb_bytes": row.get("glb_bytes", 0),
            "mesh_count": row.get("mesh_count", model.get("mesh_count", 0)),
            "triangle_count": triangles,
            "vertex_count": vertices,
            "source_mesh_bounds_extents": extents,
            "source_texture_names": texture_names,
            "motion_chunk_count": row.get("motion_chunk_count", model.get("motion_count", 0)),
            "texture_path": texture,
            "decoded_texture_file_present": bool(texture_path and texture_path.is_file()),
            "geometry_gate": "PASS_BASIC_NONDEGENERATE" if geometry_ok else "REJECT_DEGENERATE_OR_INSUFFICIENT_GEOMETRY",
            "texture_binding_verified": False,
            "item_id_join_verified": False,
            "source_identity_verified": False,
            "status": "CONVERTED_CANDIDATE_REQUIRES_ITEM_JOIN_AND_VISUAL_REVIEW" if geometry_ok else "REJECTED_GEOMETRY_GATE",
        })
    summary = []
    for family in FAMILIES:
        records = grouped.get(family, [])
        rejected = sum(1 for record in records if record["geometry_gate"] != "PASS_BASIC_NONDEGENERATE")
        summary.append({
            "family": family,
            "converted_candidate_count": len(records),
            "basic_geometry_rejected_count": rejected,
            "status": "CANDIDATES_REQUIRE_MAPPING_AND_VISUAL_REVIEW" if records and rejected == 0 else ("CANDIDATES_WITH_GEOMETRY_REJECTIONS" if records else "NO_CONVERTED_CANDIDATE_FOUND"),
            "records": records,
        })
    result = {
        "schema_version": "1.0.0",
        "source_report": str(args.audit),
        "converted_record_count": len(converted),
        "equipment_candidate_count": sum(len(v) for v in grouped.values()),
        "family_counts": dict(Counter({k: len(v) for k, v in grouped.items()})),
        "families": summary,
        "unresolved_gates": [
            "Join each C3 model ID to the version-matched Mobile 1.1.2.3 itemtype and equipment mapping tables.",
            "Verify source identity, slot, class/gender compatibility and paid/free classification from documented fields.",
            "Verify decoded PVR-to-C3 texture binding, UVs, alpha, normals, material appearance and effect links.",
            "Verify skeleton/socket attachment and actual in-game alignment on all relevant body rigs.",
            "Capture close-up runtime evidence and target-device performance before acceptance.",
        ],
        "policy": "This is an inventory and prioritization report only. A successful C3 parse, GLB export, or texture file match does not approve an asset.",
        "production_acceptance": "BLOCKED_NOT_APPROVED",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("C3_EQUIPMENT_FAMILY_AUDIT_OK", result["equipment_candidate_count"])
    for row in summary:
        print(row["family"], row["converted_candidate_count"], row["status"])

if __name__ == "__main__":
    main()
