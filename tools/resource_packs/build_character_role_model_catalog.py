#!/usr/bin/env python3
"""Build source-backed, non-approved Mobile role -> simple-object -> C3 candidates."""
from __future__ import annotations

import configparser
import hashlib
import json
import re
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


def decode_source_text(path: Path) -> tuple[str, str]:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "gb18030", "cp1252"):
        try:
            return raw.decode(encoding), encoding
        except UnicodeDecodeError:
            pass
    return raw.decode("utf-8", errors="replace"), "utf-8-replacement"


def parse_ini(path: Path) -> dict[str, dict[str, str]]:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    text, _encoding = decode_source_text(path)
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
    simple_by_section: dict[str, dict] = {}
    def normalized_fields(fields: dict[str, str]) -> dict[str, str]:
        return {re.sub(r"[^a-z0-9]", "", key.lower()): value for key, value in fields.items()}
    def numeric_field(fields: dict[str, str], aliases: tuple[str, ...]) -> int:
        normalized = normalized_fields(fields)
        for alias in aliases:
            value = normalized.get(alias, "").strip()
            if value.isdigit():
                return int(value)
        return 0
    for section_name, fields in simple_sections.items():
        normalized = normalized_fields(fields)
        simple_id = numeric_field(fields, ("3dsimpleobjid", "simpleobjid"))
        if simple_id <= 0:
            continue
        standby_id = numeric_field(fields, ("3dstandbymotion", "3dstandbymotionid", "standbymotion"))
        blaze_id = numeric_field(fields, ("3dblazemotion", "3dblazemotionid", "blazemotion"))
        simple = simple_by_id.get(simple_id)
        row = {
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
            "source_field_keys": sorted(fields.keys()),
            "mapping_status": "SOURCE_JOIN_CANDIDATE_ONLY_NOT_CLASS_OR_GENDER_APPROVED",
        }
        role_rows.append(row)
        simple_by_section[section_name] = row

    choose_sections = parse_ini(role_choose_path)
    choose = choose_sections.get("proAni", {})
    indices = choose_sections.get("proIndex", {})
    selection_rows = []
    direct_section_joins = 0
    source_identity_candidates = 0
    joined_source_role_identities = 0
    for key, animation_role in sorted(choose.items()):
        slot = key.removeprefix("pro_")
        index_key = "index_" + slot
        profession_index = indices.get(index_key, "").strip()
        # rolechoose.ini stores a numeric profession index, while
        # 3dsimplerole.ini names the matching sections Role0..Role7.
        # Resolve only this exact source-key relation; do not infer any
        # additional class/gender identities from ordering or model IDs.
        role_section_key = f"Role{profession_index}" if profession_index.isdigit() else ""
        joined_role = simple_by_section.get(role_section_key)
        if joined_role is not None:
            direct_section_joins += 1
        # Preserve explicit class/gender tokens from the UI source separately
        # from model resolution. A role-index join does not prove that its model
        # parts or final profession appearance have been resolved.
        identity_match = re.fullmatch(r"Role_(Male|Female)([A-Za-z]+)", animation_role)
        source_identity = None
        if identity_match:
            source_identity_candidates += 1
            source_identity = {
                "gender": identity_match.group(1).lower(),
                "class_token": identity_match.group(2),
                "identity_source": "rolechoose.ini proAni key",
                "identity_status": "SOURCE_LABEL_AND_ROLE_INDEX_JOINED_MODEL_ASSET_UNRESOLVED" if joined_role is not None else "SOURCE_LABEL_ONLY_ROLE_INDEX_JOIN_UNRESOLVED",
            }
            if joined_role is not None:
                joined_source_role_identities += 1
        elif animation_role.startswith("Role_"):
            source_identity = {
                "gender": None,
                "class_token": animation_role.removeprefix("Role_"),
                "identity_source": "rolechoose.ini proAni key",
                "identity_status": "SOURCE_ROLE_LABEL_ONLY_GENDER_OR_PROFESSION_NORMALIZATION_PENDING",
            }
        selection_rows.append({
            "slot": int(slot) if slot.isdigit() else slot,
            "animation_role": animation_role,
            "profession_index": profession_index,
            "role_section_key_candidate": role_section_key or None,
            "source_role_identity": source_identity,
            "simple_role_join": {
                "source_section": joined_role["source_section"],
                "simple_object_id": joined_role["simple_object_id"],
            } if joined_role is not None else None,
            "mapping_status": "DIRECT_SOURCE_ROLE_INDEX_JOIN_CANDIDATE_NOT_CLASS_GENDER_APPROVED" if joined_role is not None else "UI_ROLE_TO_SIMPLE_ROLE_JOIN_NOT_ESTABLISHED",
        })

    # Inspect every source-side character-selection registry as evidence.
    # These files may contain UI model keys that are not represented in
    # 3dsimplerole.ini; preserve the raw parsed sections without approving
    # a class/gender mapping from a numeric coincidence.
    ui_registry_sources = []
    for wanted_name in ("rolechoose_js.ini", "selectcharacter.ini"):
        for source_path in sorted(RESOURCE.rglob(wanted_name)):
            try:
                sections = parse_ini(source_path)
                ui_registry_sources.append({
                    "path": source_path.relative_to(ROOT).as_posix(),
                    "section_count": len(sections),
                    "sections": sections,
                    "parse_status": "PARSED",
                })
            except (configparser.Error, UnicodeDecodeError) as error:
                ui_registry_sources.append({
                    "path": source_path.relative_to(ROOT).as_posix(),
                    "section_count": 0,
                    "sections": {},
                    "parse_status": "PARSE_FAILED",
                    "error": str(error),
                })

    # The Mobile selection UI also has a separate six-slot registry.
    # Its proAni/proIndex pair is an explicit source relation to Role0..Role7;
    # retain that evidence separately from unresolved model-part paths.
    js_registry = next((row for row in ui_registry_sources
                        if row["path"].endswith("/rolechoose_js.ini")
                        and row["parse_status"] == "PARSED"), None)
    js_role_rows = []
    if js_registry:
        js_sections = js_registry["sections"]
        js_animations = js_sections.get("proAni", {})
        js_indices = js_sections.get("proIndex", {})
        for key, animation_role in sorted(js_animations.items()):
            slot = key.removeprefix("pro_")
            profession_index = js_indices.get("index_" + slot, "").strip()
            role_section_key = f"Role{profession_index}" if profession_index.isdigit() else ""
            joined_role = simple_by_section.get(role_section_key)
            identity_match = re.fullmatch(r"Role_(Male|Female)([A-Za-z]+)", animation_role)
            identity = ({
                "gender": identity_match.group(1).lower(),
                "class_token": identity_match.group(2),
            } if identity_match else {
                "gender": None,
                "class_token": animation_role.removeprefix("Role_"),
            })
            js_role_rows.append({
                "slot": int(slot) if slot.isdigit() else slot,
                "animation_role": animation_role,
                "profession_index": profession_index,
                "role_section_key": role_section_key or None,
                "source_identity": identity,
                "simple_role_join": ({
                    "source_section": joined_role["source_section"],
                    "simple_object_id": joined_role["simple_object_id"],
                } if joined_role else None),
                "mapping_status": (
                    "SOURCE_CLASS_GENDER_AND_SIMPLE_ROLE_JOIN_CONFIRMED_MODEL_ASSET_UNRESOLVED"
                    if joined_role and identity_match
                    else "SOURCE_ROLE_JOIN_INCOMPLETE"
                ),
            })

    # Cross-reference exact numeric keys from the simple-role table against
    # text configuration files. This is a discovery report only: a hit is
    # not promoted unless a direct source relation and visual/rig checks exist.
    candidate_tokens = set()
    for row in role_rows:
        for field_name in ("simple_object_id", "standby_motion_id", "blaze_motion_id"):
            value = int(row.get(field_name, 0) or 0)
            if value > 0:
                candidate_tokens.add(str(value))
        simple = row.get("simple_object")
        if isinstance(simple, dict):
            for part in simple.get("parts", []):
                if not isinstance(part, dict):
                    continue
                for field_name in ("part_id", "texture_id"):
                    value = int(part.get(field_name, 0) or 0)
                    if value > 0:
                        candidate_tokens.add(str(value))

    reference_hits = []
    searched_ini_count = 0
    for source_path in sorted(RESOURCE.rglob("*.ini")):
        try:
            source_text, encoding = decode_source_text(source_path)
        except OSError:
            continue
        searched_ini_count += 1
        for line_number, line in enumerate(source_text.splitlines(), start=1):
            for token in candidate_tokens:
                if re.search(rf"(?<![0-9]){re.escape(token)}(?![0-9])", line):
                    reference_hits.append({
                        "token": token,
                        "path": source_path.relative_to(ROOT).as_posix(),
                        "line": line_number,
                        "encoding": encoding,
                        "text": line.strip()[:500],
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
        "rolechoose_js_source_role_joins": js_role_rows,
        "additional_ui_registry_sources": ui_registry_sources,
        "role_source_cross_reference": {
            "searched_ini_file_count": searched_ini_count,
            "candidate_token_count": len(candidate_tokens),
            "reference_hit_count": len(reference_hits),
            "unmatched_candidate_tokens": sorted(candidate_tokens - {row["token"] for row in reference_hits}),
            "hits": reference_hits,
            "status": "DISCOVERY_ONLY_NO_CLASS_OR_GENDER_MAPPING_APPROVED",
        },
        "rolepart": mesh_catalog.get("role_parts", {}),
        "summary": {
            "simple_role_records": len(role_rows),
            "simple_object_ids_found": sum(1 for row in role_rows if row["simple_object_found"]),
            "standby_motion_ids_found": sum(1 for row in role_rows if row["standby_motion_paths"]),
            "blaze_motion_ids_found": sum(1 for row in role_rows if row["blaze_motion_paths"]),
            "selection_ui_slots": len(selection_rows),
            "selection_ui_direct_section_join_candidates": direct_section_joins,
            "source_role_identity_candidates": source_identity_candidates,
            "joined_source_role_identities": joined_source_role_identities,
            "rolechoose_js_slots": len(js_role_rows),
            "rolechoose_js_class_gender_simple_role_joins": sum(
                1 for row in js_role_rows
                if row["mapping_status"] == "SOURCE_CLASS_GENDER_AND_SIMPLE_ROLE_JOIN_CONFIRMED_MODEL_ASSET_UNRESOLVED"
            ),
            "standby_motion_id_fields_found": sum(1 for row in role_rows if row["standby_motion_id"] > 0),
            "blaze_motion_id_fields_found": sum(1 for row in role_rows if row["blaze_motion_id"] > 0),
            "class_gender_mappings_approved": 0,
        },
        "policy": "rolechoose_js proAni/proIndex establishes explicit source class/gender-to-simple-role joins where present, but no production character model is approved until model parts, textures, rig and visual identity are resolved and validated.",
    }
    MAPPING_DIR.mkdir(parents=True, exist_ok=True)
    out = MAPPING_DIR / "role_model_candidate_catalog.json"
    out.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
