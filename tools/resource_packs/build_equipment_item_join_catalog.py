#!/usr/bin/env python3
"""Join Mobile item, mount, MESH, C3, texture and motion source records."""
import csv, hashlib, json, re
from pathlib import Path

INDEX = Path("reports/resource-source-index.csv")
MESH_CATALOG = Path("resource_stage/world/resource_mappings/mesh_equipment_catalog.json")
if not INDEX.is_file() or not MESH_CATALOG.is_file():
    raise SystemExit("Missing resource source index or MESH equipment catalog")

rows = list(csv.DictReader(INDEX.open("r", encoding="utf-8-sig", newline="")))
def inner_path(row):
    return row.get("source_path", "").split("!")[-1].replace("\\", "/").lower()

def choose_file(suffix, language="en"):
    candidates = []
    for row in rows:
        inner = inner_path(row)
        if not inner.endswith(suffix.lower()):
            continue
        if language == "en" and ("/ini_ar/" in inner or "/ini_sp/" in inner):
            continue
        if language == "ar" and "/ini_ar/" not in inner:
            continue
        staged = row.get("staged_path", "")
        if staged and Path(staged).is_file():
            candidates.append((len(inner), staged, row))
    if not candidates:
        return None, None
    _, staged, row = sorted(candidates)[0]
    return Path(staged), row

def decode_text(data, language="en"):
    for encoding in (("utf-8-sig", "cp1256", "cp1252") if language == "ar" else ("utf-8-sig", "cp1252", "latin1")):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")

def parse_pairs(text):
    section = ""
    sections = {}
    pair_count = 0
    for raw in text.splitlines():
        line = raw.strip().lstrip("\ufeff")
        if not line or line.startswith((";", "#", "//")):
            continue
        if line.startswith("[") and "]" in line:
            section = line[1:line.index("]")].strip()
            sections.setdefault(section, {})
        elif "=" in line:
            key, value = line.split("=", 1)
            sections.setdefault(section, {})[key.strip()] = value.strip()
            pair_count += 1
    return sections, pair_count

def decode_tq_9527(data):
    state = 9527 & 0xFFFFFFFF
    key = []
    for _ in range(128):
        state = (state * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        key.append(((state >> 16) & 0x7FFF) & 0xFF)
    decoded = bytearray(len(data))
    for index, value in enumerate(data):
        shifted = value ^ key[index % 128]
        shift = index % 8
        decoded[index] = shifted if shift == 0 else ((shifted >> shift) | (shifted << (8 - shift))) & 0xFF
    return bytes(decoded)

def parse_itemtypes(language):
    suffix = "ini/itemtype/"
    if language == "ar":
        suffix = "ini_ar/itemtype/"
    found = {}
    source_files = []
    for row in rows:
        inner = inner_path(row)
        if suffix not in inner or not inner.endswith(".ini"):
            continue
        staged = Path(row.get("staged_path", ""))
        if not staged.is_file():
            continue
        source_files.append(str(staged))
        text = decode_text(staged.read_bytes(), language)
        for line_no, raw in enumerate(text.splitlines(), 1):
            line = raw.strip().lstrip("\ufeff")
            if not line or line.startswith(("#", ";", "//")):
                continue
            fields = line.split("@@")
            if fields and fields[-1] == "":
                fields.pop()
            if len(fields) < 2 or not fields[0].strip().isdigit():
                continue
            item_id = fields[0].strip()
            record = {
                "item_id": item_id,
                "name": fields[1].strip(),
                "field_count": len(fields),
                "source_file": str(staged),
                "source_line": line_no,
            }
            if len(fields) > 59:
                record["opaque_field_59"] = fields[59].strip()
            # Keep raw fields for exact downstream schema work; do not assign undocumented meanings.
            record["raw_fields"] = fields
            found[item_id] = record
    return found, sorted(set(source_files))

def file_record(suffix):
    path, row = choose_file(suffix, "en")
    if path is None:
        return {}, None
    sections, pair_count = parse_pairs(decode_text(path.read_bytes()))
    return sections, {
        "path": str(path), "source_path": row.get("source_path"),
        "sha256": row.get("sha256"), "size_bytes": row.get("size_bytes"),
        "pair_count": pair_count,
    }

mesh_catalog = json.loads(MESH_CATALOG.read_text(encoding="utf-8"))
MOTION_CATALOG = Path("resource_stage/world/resource_mappings/motion_catalog.json")
motion_catalog = json.loads(MOTION_CATALOG.read_text(encoding="utf-8")) if MOTION_CATALOG.is_file() else {"tables": {}}
motion_lookups = {
    table_name: {str(record.get("motion_id")): str(record.get("motion_path", "")) for record in table.get("records", [])}
    for table_name, table in motion_catalog.get("tables", {}).items()
}
def find_motion(motion_id):
    if not motion_id:
        return []
    target = str(motion_id)
    matches = []
    for table_name, lookup in motion_lookups.items():
        path = lookup.get(target)
        if path:
            matches.append({"table": table_name, "motion_id": target, "motion_path": path})
    return matches

tables = mesh_catalog.get("tables", {})
def record_map(table_name):
    return {str(record.get("unique_id")): record for record in tables.get(table_name, {}).get("records", [])}
def part_map(table_name):
    result = {}
    for record in tables.get(table_name, {}).get("records", []):
        for part in record.get("parts", []):
            result.setdefault(str(part.get("mesh_id")), []).append(record)
    return result
mesh_records = {name: record_map(name) for name in tables}
mesh_parts = {name: part_map(name) for name in tables}

weapon_map, weapon_meta = file_record("ini/weapon_trans.ini")
armet_map, armet_meta = file_record("ini/armet_trans.ini")
armor_map, armor_meta = file_record("ini/armor_trans.ini")
weapon_type_map, weapon_type_meta = file_record("ini/weapontrans.ini")
default_res, default_res_meta = file_record("ini/defaultres.ini")
mount_info, mount_info_meta = file_record("ini/mountinfo.ini")

mounttype_path, mounttype_source = choose_file("ini/mounttype.dat", "en")
if mounttype_path is None:
    raise SystemExit("Mobile mounttype.dat was not found in the verified resource index")
mounttype_decoded = decode_tq_9527(mounttype_path.read_bytes())
mounttype_text = decode_text(mounttype_decoded)
mounttype_sections, mounttype_pair_count = parse_pairs(mounttype_text)
printable_ratio = sum(1 for b in mounttype_decoded if b in (9, 10, 13) or 32 <= b < 127) / max(1, len(mounttype_decoded))

itemtype_en, itemtype_en_files = parse_itemtypes("en")
itemtype_ar, itemtype_ar_files = parse_itemtypes("ar")

def part_paths(record):
    if not record:
        return []
    return [{
        "mesh_id": part.get("mesh_id"),
        "texture_id": part.get("texture_id"),
        "mix_texture_id": part.get("mix_texture_id"),
        "mesh_path": part.get("mesh_path"),
        "texture_path": part.get("texture_path"),
        "mix_texture_path": part.get("mix_texture_path"),
        "part_extension_f32": part.get("part_extension_f32", []),
        "mix_option": part.get("mix_option"),
        "alpha_source_blend": part.get("alpha_source_blend"),
        "alpha_destination_blend": part.get("alpha_destination_blend"),
        "material_id": part.get("material_id"),
    } for part in record.get("parts", [])]

def lookup_record(table, candidate_ids):
    for candidate in candidate_ids:
        if candidate and str(candidate) in mesh_records.get(table, {}):
            return mesh_records[table][str(candidate)], "UNIQUE_ID"
        if candidate and str(candidate) in mesh_parts.get(table, {}):
            records = mesh_parts[table][str(candidate)]
            if records:
                return records[0], "PART_MESH_ID"
    return None, "UNMATCHED"

def item_names(item_id):
    en = itemtype_en.get(str(item_id), {})
    ar = itemtype_ar.get(str(item_id), {})
    return {
        "name_en": en.get("name"),
        "name_ar": ar.get("name"),
        "itemtype_field_count": en.get("field_count"),
        "opaque_field_59": en.get("opaque_field_59"),
    }

def build_translation_rows(mapping, table_name, family):
    result = []
    matched = 0
    itemtype_matches = 0
    for section, pairs in mapping.items():
        for key, value in pairs.items():
            rec, join_kind = lookup_record(table_name, (value, key))
            names = item_names(key)
            if names.get("name_en") or names.get("name_ar"):
                itemtype_matches += 1
            if rec:
                matched += 1
            result.append({
                "mapping_section": section, "item_or_model_id": key,
                "normalized_model_id": value, **names,
                "mesh_record_id": rec.get("unique_id") if rec else None,
                "join_kind": join_kind,
                "mesh_parts": part_paths(rec),
                "status": "MESH_SOURCE_JOINED_REQUIRES_RUNTIME_VISUAL_REVIEW" if rec else "NO_DIRECT_MESH_JOIN",
            })
    return {
        "pair_count": len(result), "itemtype_name_match_count": itemtype_matches,
        "mesh_record_join_count": matched, "records": result,
    }

weapon_items = build_translation_rows(weapon_map, "ini/weapon.dbc", "weapon")
armet_items = build_translation_rows(armet_map, "ini/armet.dbc", "armet")
armor_items = build_translation_rows(armor_map, "ini/armor.dbc", "armor")

mount_records = mesh_records.get("ini/mount.dbc", {})
mount_items = []
mount_armor_ref_count = mount_armor_match_count = 0
for item_id, props in mounttype_sections.items():
    armor_id = str(props.get("armor", "")).strip()
    rec = mount_records.get(armor_id)
    motion_set_id = str(rec.get("motion_set_mesh_id", "")) if rec else ""
    motion_set_path = str(rec.get("motion_set_mesh_path", "")).replace("\\", "/").lower() if rec else ""
    motion_set = mesh_catalog.get("mount_motion_sets", {}).get(motion_set_path) if motion_set_path else None
    if armor_id:
        mount_armor_ref_count += 1
    if rec:
        mount_armor_match_count += 1
    names = item_names(item_id)
    mount_items.append({
        "mount_item_id": item_id,
        "armor_mesh_record_id": armor_id or None,
        **names,
        "properties": props,
        "mesh_parts": part_paths(rec),
        "motion_set_mesh_id": motion_set_id or None,
        "motion_set_mesh_path": motion_set_path or None,
        "motion_set_base_mesh_ids": motion_set.get("base_mesh_ids", []) if motion_set else [],
        "motion_set_source_record_ids": motion_set.get("source_record_ids", []) if motion_set else [],
        "motion_set_record_count": motion_set.get("record_count", 0) if motion_set else 0,
        "motion_set_unique_path_count": motion_set.get("unique_path_count", 0) if motion_set else 0,
        "status": ("MESH_AND_MOTION_SOURCE_JOINED_REQUIRES_RUNTIME_PLAYBACK" if rec and motion_set else ("MESH_SOURCE_JOINED_MOTION_NOT_MAPPED" if rec else "MOUNT_MESH_ID_NOT_FOUND")),
    })

default_resources = []
for section, props in default_res.items():
    model_id = str(props.get("id", "")).strip()
    candidate_tables = ["ini/mount.dbc", "ini/armet.dbc", "ini/armet1.dbc", "ini/armor.dbc", "ini/weapon.dbc", "ini/head.dbc", "ini/misc.dbc"]
    matches = []
    for table_name in candidate_tables:
        rec, join_kind = lookup_record(table_name, (model_id,))
        if rec:
            matches.append({"table": table_name, "mesh_record_id": rec.get("unique_id"), "join_kind": join_kind, "mesh_parts": part_paths(rec)})
    motion_id = str(props.get("motionid", "")).strip()
    default_resources.append({
        "section": section, "properties": props, "model_id": model_id or None,
        "matches": matches, "motion_matches": find_motion(motion_id),
    })

default_mount = next((row for row in default_resources if row.get("section", "").lower() == "mount"), None)
default_mount_model_id = str(default_mount.get("model_id", "")) if default_mount else ""
default_mount_motion_id = str(default_mount.get("properties", {}).get("motionid", "")) if default_mount else ""
default_mount_mesh_record, default_mount_mesh_join_kind = lookup_record("ini/mount.dbc", (default_mount_model_id,))
default_mount_motion_matches = find_motion(default_mount_motion_id)
default_mount_motion_set_id = str(default_mount_mesh_record.get("motion_set_mesh_id", "")) if default_mount_mesh_record else ""
default_mount_motion_set_path = str(default_mount_mesh_record.get("motion_set_mesh_path", "")).replace("\\", "/").lower() if default_mount_mesh_record else ""
default_mount_motion_set = mesh_catalog.get("mount_motion_sets", {}).get(default_mount_motion_set_path) if default_mount_motion_set_path else None
default_mountmotion_paths = [
    str(row.get("motion_path", ""))
    for row in (default_mount_motion_set or {}).get("motion_records", [])
    if row.get("motion_path")
]
default_3dmotion_paths = [row["motion_path"] for row in default_mount_motion_matches if row.get("motion_path")]
defaultres_motion_id_matches_model_id = bool(default_mount_model_id and default_mount_motion_id and int(default_mount_motion_id) // 1000 == int(default_mount_model_id))
defaultres_mesh_matches_motion_set = bool(default_mount_motion_set and default_mount_motion_set_path == str((default_mount_mesh_record or {}).get("parts", [{}])[0].get("mesh_path", "")).replace("\\", "/").lower())
default_mount_cross_table_match = defaultres_motion_id_matches_model_id and defaultres_mesh_matches_motion_set and bool(default_mountmotion_paths)
mount_items_with_motion = sum(1 for row in mount_items if row.get("motion_set_mesh_id") is not None)
mount_motion_paths = sorted({
    str(path)
    for motion_set in mesh_catalog.get("mount_motion_sets", {}).values()
    for motion in motion_set.get("motion_records", [])
    for path in [motion.get("motion_path")]
    if path
})

# Keep only source itemtype records referenced by translation maps, MESH IDs/part IDs, or mount IDs.
candidate_ids = set()
for mapping in (weapon_map, armet_map, armor_map):
    for pairs in mapping.values():
        for key, value in pairs.items():
            candidate_ids.add(str(key)); candidate_ids.add(str(value))
for table in tables.values():
    for record in table.get("records", []):
        candidate_ids.add(str(record.get("unique_id")))
        for part in record.get("parts", []):
            candidate_ids.add(str(part.get("mesh_id")))
            candidate_ids.add(str(part.get("texture_id")))
for item_id in mounttype_sections:
    candidate_ids.add(str(item_id))
itemtype_records = {
    item_id: {"en": itemtype_en.get(item_id), "ar": itemtype_ar.get(item_id)}
    for item_id in sorted(candidate_ids)
    if item_id in itemtype_en or item_id in itemtype_ar
}

mount_join_ratio = mount_armor_match_count / max(1, mount_armor_ref_count)
mount_cipher_status = "CROSS_REFERENCE_VALIDATED_AGAINST_MOBILE_MESH_TABLE" if printable_ratio > 0.98 and mount_join_ratio > 0.8 else "PLAUSIBLE_DECODE_REQUIRES_MORE_SOURCE_CROSS_CHECKS"

catalog = {
    "schema_version": "1.0.0",
    "source_version": "Conquer Mobile 1.1.2.3",
    "source_tables": {
        "mesh_equipment_catalog": {"path": str(MESH_CATALOG), "sha256": hashlib.sha256(MESH_CATALOG.read_bytes()).hexdigest()},
        "weapon_trans": weapon_meta, "armet_trans": armet_meta, "armor_trans": armor_meta,
        "weapontrans": weapon_type_meta, "defaultres": default_res_meta,
        "mountinfo": mount_info_meta,
        "mounttype": {"path": str(mounttype_path), "source_path": mounttype_source.get("source_path"), "sha256": hashlib.sha256(mounttype_path.read_bytes()).hexdigest(), "cipher_seed_candidate": 9527},
        "motion_catalog": {"path": str(MOTION_CATALOG) if MOTION_CATALOG.is_file() else None, "sha256": hashlib.sha256(MOTION_CATALOG.read_bytes()).hexdigest() if MOTION_CATALOG.is_file() else None},
    },
    "weapon_items": weapon_items,
    "armet_translation_items": armet_items,
    "armor_translation_items": armor_items,
    "mount_items": {
        "section_count": len(mounttype_sections),
        "key_value_pair_count": mounttype_pair_count,
        "armor_mesh_reference_count": mount_armor_ref_count,
        "armor_mesh_record_match_count": mount_armor_match_count,
        "armor_mesh_join_ratio": round(mount_join_ratio, 6),
        "mount_items_with_motion_records": mount_items_with_motion,
        "unique_mount_motion_path_count": len(mount_motion_paths),
        "cipher_printable_ratio": round(printable_ratio, 6),
        "cipher_validation": mount_cipher_status,
        "default_mount_cross_table_check": {
            "defaultres_mount_model_id": default_mount_model_id,
            "defaultres_motion_id": default_mount_motion_id,
            "mount_mesh_record_id": default_mount_mesh_record.get("unique_id") if default_mount_mesh_record else None,
            "mount_mesh_join_kind": default_mount_mesh_join_kind,
            "motion_set_mesh_id": default_mount_motion_set_id or None,
            "motion_set_mesh_path": default_mount_motion_set_path or None,
            "defaultres_motion_id_divided_by_1000_matches_model_id": defaultres_motion_id_matches_model_id,
            "defaultres_mesh_record_has_motion_set": defaultres_mesh_matches_motion_set,
            "mountmotion_paths": default_mountmotion_paths[:100],
            "defaultres_3dmotion_paths": default_3dmotion_paths[:20],
            "cross_table_motion_mapping_validated": default_mount_cross_table_match,
            "status": "DEFAULTRES_MODEL_ID_AND_MOUNTMOTION_SET_AGREE" if default_mount_cross_table_match else "CROSS_TABLE_MOTION_CHECK_INCOMPLETE",
        },
        "records": mount_items,
    },
    "default_resources": default_resources,
    "mount_action_translations": mount_info,
    "weapon_type_translations": weapon_type_map,
    "itemtype_records_for_joined_ids": itemtype_records,
    "itemtype_source_files_en": itemtype_en_files,
    "itemtype_source_files_ar": itemtype_ar_files,
    "schema_policy": "All unverified itemtype fields remain raw source columns; field 59 is retained as an opaque candidate and is not labeled as price or premium currency without a Mobile 1.1.2.3 schema proof.",
    "status": "SOURCE_LINKED_CANDIDATE_REQUIRES_RUNTIME_VISUAL_REVIEW",
}
out = Path("resource_stage/world/resource_mappings/equipment_item_join_catalog.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

summary = {
    "schema_version": "1.0.0",
    "weapon_trans": {k: v for k, v in weapon_items.items() if k != "records"} | {"sample_unmatched": [r for r in weapon_items["records"] if r["status"] == "NO_DIRECT_MESH_JOIN"][:50]},
    "armet_trans": {k: v for k, v in armet_items.items() if k != "records"} | {"sample_unmatched": [r for r in armet_items["records"] if r["status"] == "NO_DIRECT_MESH_JOIN"][:50]},
    "armor_trans": {k: v for k, v in armor_items.items() if k != "records"} | {"sample_unmatched": [r for r in armor_items["records"] if r["status"] == "NO_DIRECT_MESH_JOIN"][:50]},
    "mounttype": {
        "section_count": len(mounttype_sections), "key_value_pair_count": mounttype_pair_count,
        "armor_mesh_reference_count": mount_armor_ref_count, "armor_mesh_record_match_count": mount_armor_match_count,
        "armor_mesh_join_ratio": round(mount_join_ratio, 6), "cipher_printable_ratio": round(printable_ratio, 6),
        "cipher_validation": mount_cipher_status,
        "mount_items_with_motion_records": mount_items_with_motion,
        "unique_mount_motion_path_count": len(mount_motion_paths),
        "default_mount_cross_table_check": {
            "defaultres_mount_model_id": default_mount_model_id,
            "defaultres_motion_id": default_mount_motion_id,
            "mount_mesh_record_id": default_mount_mesh_record.get("unique_id") if default_mount_mesh_record else None,
            "motion_set_mesh_id": default_mount_motion_set_id or None,
            "defaultres_motion_id_divided_by_1000_matches_model_id": defaultres_motion_id_matches_model_id,
            "defaultres_mesh_record_has_motion_set": defaultres_mesh_matches_motion_set,
            "cross_table_motion_mapping_validated": default_mount_cross_table_match,
            "mountmotion_paths": default_mountmotion_paths[:100],
            "defaultres_3dmotion_paths": default_3dmotion_paths[:20],
        },
        "unmatched_mount_samples": [r for r in mount_items if r["status"] == "MOUNT_MESH_ID_NOT_FOUND"][:50],
    },
    "default_resource_section_count": len(default_resources),
    "default_resource_motion_match_count": sum(len(r.get("motion_matches", [])) for r in default_resources),
    "motion_catalog_unique_path_count": motion_catalog.get("unique_motion_path_count", 0),
    "itemtype_join_record_count": len(itemtype_records),
    "catalog_path": str(out),
    "catalog_sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
    "status": "SOURCE_LINKED_CANDIDATE_REQUIRES_RUNTIME_VISUAL_REVIEW",
}
report_path = Path("reports/equipment-item-join-audit.json")
report_path.parent.mkdir(parents=True, exist_ok=True)
report_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("EQUIPMENT_ITEM_JOIN_AUDIT", json.dumps({
    "weapon_trans": {k: weapon_items[k] for k in ("pair_count", "itemtype_name_match_count", "mesh_record_join_count")},
    "armet_trans": {k: armet_items[k] for k in ("pair_count", "itemtype_name_match_count", "mesh_record_join_count")},
    "armor_trans": {k: armor_items[k] for k in ("pair_count", "itemtype_name_match_count", "mesh_record_join_count")},
    "mounttype": {"sections": len(mounttype_sections), "armor_mesh_matches": mount_armor_match_count, "ratio": round(mount_join_ratio, 4), "cipher": mount_cipher_status},
    "itemtype_records": len(itemtype_records),
}, ensure_ascii=False))
