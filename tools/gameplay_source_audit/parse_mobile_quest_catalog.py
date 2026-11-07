#!/usr/bin/env python3
"""Parse readable Mobile 1.1.2.3 quest INI records and report source-linked references.

This is a research catalogue builder, not a runtime importer. Unknown fields remain
opaque, IDs retain their original strings, and all source files are fingerprinted.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import struct
from collections import Counter, defaultdict
from pathlib import Path

def decode(path: Path) -> str:
    raw = path.read_bytes()
    for enc in ("utf-8-sig", "utf-8", "gb18030", "cp1252", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            pass
    return raw.decode("utf-8", errors="replace")

def parse_sections(text: str):
    rows, current = [], None
    for line_no, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith((";", "#", "//")):
            continue
        if line.startswith("[") and "]" in line:
            name = line[1:line.index("]")].strip()
            current = {"section": name, "line": line_no, "fields": {}}
            rows.append(current)
        elif current is not None and "=" in line:
            key, value = line.split("=", 1)
            current["fields"][key.strip()] = value.strip()
    return rows

def integer(value):
    try:
        return int(value, 10)
    except (TypeError, ValueError):
        return None

def parse_npc_location(raw: str):
    parts = [x.strip() for x in raw.split(",")]
    if parts == ["0"] or not raw:
        return {"status": "NO_NPC", "raw": raw}
    if len(parts) == 6:
        npc_id, map_id, x, y, npc_name, map_name = parts
    elif len(parts) == 5:
        npc_id, map_id, x, y, map_name = parts
        npc_name = ""
    else:
        return {"status": "UNPARSED", "raw": raw, "parts": parts}
    return {
        "status": "PARSED", "npc_id": npc_id, "map_id": map_id,
        "x": integer(x), "y": integer(y), "npc_name": npc_name,
        "map_name": map_name, "raw": raw,
    }

def parse_intention(raw: str):
    refs = []
    for match in re.finditer(r"\[([^\]]+)\]", raw or ""):
        token = match.group(1).strip()
        head, _, payload = token.partition(" ")
        parts = [x.strip() for x in payload.split(",")] if payload else []
        ref = {"kind": head, "raw": token, "parts": parts}
        if head == "npc" and len(parts) >= 5:
            ref.update({
                "npc_name": parts[0], "npc_id": parts[1], "map_id": parts[2],
                "x": integer(parts[3]), "y": integer(parts[4]),
            })
        elif head == "mob" and len(parts) >= 4:
            ref.update({
                "monster_name": parts[0], "map_id": parts[1],
                "x": integer(parts[2]), "y": integer(parts[3]),
            })
        elif head == "item_t" and len(parts) >= 4:
            ref.update({
                "item_name": parts[0], "map_id": parts[1],
                "x": integer(parts[2]), "y": integer(parts[3]),
            })
        elif head == "chk_item" and len(parts) >= 2:
            ref.update({"item_id": parts[0], "quantity": integer(parts[1])})
        elif head == "chk_quest" and parts:
            ref.update({"quest_id": parts[0]})
        elif head == "map" and len(parts) >= 4:
            ref.update({
                "map_name": parts[0], "map_id": parts[1],
                "x": integer(parts[2]), "y": integer(parts[3]),
            })
        elif head == "lua" and parts:
            ref.update({"script_name": parts[0]})
        refs.append(ref)
    return refs

def parse_gamemap(path: Path):
    if not path.is_file():
        return {"status": "MISSING", "records": [], "error": "gamemap.dat absent"}
    data = path.read_bytes()
    if len(data) < 4:
        return {"status": "INVALID", "records": [], "error": "short header"}
    count = struct.unpack_from("<I", data, 0)[0]
    pos, records = 4, []
    try:
        for _ in range(count):
            map_id, length = struct.unpack_from("<II", data, pos)
            pos += 8
            if length > 4096 or pos + length + 4 > len(data):
                raise ValueError("path length out of bounds")
            map_path = data[pos:pos+length].decode("utf-8", errors="replace")
            pos += length
            flags = struct.unpack_from("<I", data, pos)[0]
            pos += 4
            records.append({"map_id": str(map_id), "resource_path": map_path, "flags": flags})
        if pos != len(data):
            raise ValueError(f"trailing bytes: {len(data)-pos}")
    except (struct.error, ValueError) as exc:
        return {"status": "INVALID", "records": records, "error": str(exc), "declared_count": count}
    return {"status": "STRUCTURE_PARSED_ID_PATH_FLAGS_ONLY", "declared_count": count, "records": records}

def source_meta(path: Path):
    raw = path.read_bytes()
    return {"path": str(path), "size_bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source_dir", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    root = args.source_dir
    locale_paths = {
        "default": root/"ini/questinfo.ini",
        "ar": root/"ini_ar/questinfo.ini",
        "sp": root/"ini_sp/questinfo.ini",
    }
    locale_data, locale_ids, locale_summary = {}, {}, {}
    for locale, path in locale_paths.items():
        if not path.is_file():
            locale_summary[locale] = {"status": "MISSING", "record_count": 0, "mission_id_count": 0}
            continue
        sections = parse_sections(decode(path))
        quests = [s for s in sections if s["section"].isdigit()]
        records = []
        for section in quests:
            f = section["fields"]
            intentions = []
            for key, value in f.items():
                if re.fullmatch(r"Intention\d+", key):
                    intentions.extend([{"field": key, **r} for r in parse_intention(value)])
            begin = parse_npc_location(f.get("BeginNpcId", ""))
            finish = parse_npc_location(f.get("FinishNpcId", ""))
            prereqs = [x.strip() for x in f.get("Prequest", "").split("|") if x.strip() and x.strip() not in ("0", "-1")]
            prize = f.get("Prize", "")
            item_rewards = re.findall(r"\[item\s+(\d+)\s*,\s*([^\]]*)\]", prize, flags=re.I)
            records.append({
                "section": section["section"], "source_line": section["line"],
                "mission_id": f.get("MissionId", ""), "name": f.get("Name", ""),
                "type_id": f.get("TypeId", ""), "big_type_id": f.get("BigTypeId", ""),
                "level_min": integer(f.get("Lv_min")), "level_max": integer(f.get("Lv_max")),
                "profession": f.get("Profession", ""), "sex": f.get("Sex", ""),
                "activity_type": f.get("ActivityType", ""), "activity_begin": f.get("ActivityBeginTime", ""),
                "activity_end": f.get("ActivityEndTime", ""), "finish_time": f.get("FinishTime", ""),
                "repeat_or_abandon": f.get("IsCanAbondon", ""), "auto": f.get("Auto", ""),
                "first": f.get("First", ""), "prequest_raw": f.get("Prequest", ""),
                "prerequisite_mission_ids": prereqs, "map_field": f.get("Map", ""),
                "begin_npc": begin, "finish_npc": finish,
                "prize_raw": prize, "reward_item_candidates": [{"item_id": a, "opaque_item_payload": b} for a,b in item_rewards],
                "intention_count": integer(f.get("IntentAmount")),
                "intention_description": f.get("IntentionDesp", ""),
                "intentions": intentions, "content": f.get("Content", ""),
            })
        ids = [r["mission_id"] for r in records if r["mission_id"]]
        locale_ids[locale] = set(ids)
        locale_data[locale] = records
        duplicates = sorted(k for k,v in Counter(ids).items() if v > 1)
        locale_summary[locale] = {
            "status": "PARSED", "declared_total_mission": next((integer(s["fields"].get("TotalMission")) for s in sections if s["section"]=="TotalMission"), None),
            "record_count": len(records), "mission_id_count": len(set(ids)),
            "duplicate_mission_ids": duplicates,
            "begin_npc_present": sum(r["begin_npc"]["status"]=="PARSED" for r in records),
            "begin_npc_missing_or_zero": sum(r["begin_npc"]["status"]!="PARSED" for r in records),
            "finish_npc_present": sum(r["finish_npc"]["status"]=="PARSED" for r in records),
            "finish_npc_missing_or_zero": sum(r["finish_npc"]["status"]!="PARSED" for r in records),
            "intention_token_counts": dict(sorted(Counter(ref["kind"] for r in records for ref in r["intentions"]).items())),
        }
    union_ids = set().union(*locale_ids.values()) if locale_ids else set()
    for locale, records in locale_data.items():
        missing = sorted({p for r in records for p in r["prerequisite_mission_ids"] if p not in locale_ids[locale]})
        missing_union = sorted({p for r in records for p in r["prerequisite_mission_ids"] if p not in union_ids})
        locale_summary[locale]["unresolved_prerequisites_in_locale"] = missing
        locale_summary[locale]["unresolved_prerequisites_across_locales"] = missing_union

    default_records = locale_data.get("default", [])
    npc_types_path = root/"ini/npc.ini"
    npc_types = parse_sections(decode(npc_types_path)) if npc_types_path.is_file() else []
    name_to_types = defaultdict(list)
    for sec in npc_types:
        if sec["section"].lower().startswith("npctype"):
            name = sec["fields"].get("Name", "").strip()
            if name:
                name_to_types[name.casefold()].append(sec["section"])
    npc_refs = []
    map_refs = []
    mob_refs = []
    item_refs = []
    for q in default_records:
        for field in ("begin_npc", "finish_npc"):
            n = q[field]
            if n.get("status") == "PARSED":
                npc_refs.append({"mission_id": q["mission_id"], "role": field, **n})
                map_refs.append({"mission_id": q["mission_id"], "role": field, "map_id": n["map_id"], "x": n["x"], "y": n["y"]})
        for r in q["intentions"]:
            if r["kind"] == "npc" and "npc_id" in r:
                matches = name_to_types.get(r["npc_name"].casefold(), [])
                npc_refs.append({"mission_id": q["mission_id"], "role": r["field"], **r, "npc_type_name_matches": matches})
                map_refs.append({"mission_id": q["mission_id"], "role": r["field"], "map_id": r["map_id"], "x": r["x"], "y": r["y"]})
            elif r["kind"] == "mob" and "map_id" in r:
                mob_refs.append({"mission_id": q["mission_id"], **r})
                map_refs.append({"mission_id": q["mission_id"], "role": r["field"], "map_id": r["map_id"], "x": r["x"], "y": r["y"]})
            elif r["kind"] == "item_t" and "map_id" in r:
                item_refs.append({"mission_id": q["mission_id"], **r})
                map_refs.append({"mission_id": q["mission_id"], "role": r["field"], "map_id": r["map_id"], "x": r["x"], "y": r["y"]})
            elif r["kind"] == "map" and "map_id" in r:
                map_refs.append({"mission_id": q["mission_id"], "role": r["field"], "map_id": r["map_id"], "x": r["x"], "y": r["y"]})
    gm = parse_gamemap(root/"ini/gamemap.dat")
    known_maps = {r["map_id"] for r in gm.get("records", [])}
    map_ref_ids = sorted({r["map_id"] for r in map_refs if r.get("map_id")})
    npc_name_match_counts = Counter()
    for r in npc_refs:
        if r.get("npc_name"):
            npc_name_match_counts["matched" if name_to_types.get(r["npc_name"].casefold()) else "unmatched"] += 1
    report = {
        "schema_version": "1.0.0",
        "source_version": "Conquer Online Mobile 1.1.2.3",
        "evidence_status": "SOURCE_READABLE_SCHEMA_SEMANTICS_PARTIALLY_UNVERIFIED",
        "policy": "questinfo.ini is parsed as readable INI source. NPC/map/objective links are source values; NPC type-name joins are candidate joins only. No runtime import is approved by this report.",
        "source_files": [source_meta(p) for p in [locale_paths["default"], locale_paths["ar"], locale_paths["sp"], npc_types_path, root/"ini/gamemap.dat", root/"ini/gamemapex.ini", root/"ini/mapdestination.ini"] if p.is_file()],
        "locale_summary": locale_summary,
        "mission_catalog": default_records,
        "cross_reference_summary": {
            "unique_default_mission_ids": len({r["mission_id"] for r in default_records if r["mission_id"]}),
            "npc_reference_count": len(npc_refs),
            "unique_npc_ids": len({r["npc_id"] for r in npc_refs if r.get("npc_id")}),
            "npc_name_to_npc_type_match_counts": dict(npc_name_match_counts),
            "unique_map_ids_referenced": len(map_ref_ids),
            "map_ids_in_gamemap_dat": len(known_maps),
            "map_reference_ids_missing_from_gamemap_dat": sorted(set(map_ref_ids)-known_maps),
            "mob_reference_count": len(mob_refs),
            "unique_monster_names": len({r.get("monster_name") for r in mob_refs}),
            "item_world_reference_count": len(item_refs),
            "unique_item_world_names": len({r.get("item_name") for r in item_refs}),
        },
        "npc_references": npc_refs,
        "map_references": map_refs,
        "mob_references": mob_refs,
        "item_world_references": item_refs,
        "gamemap_catalog": gm,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"locale_summary": locale_summary, "cross_reference_summary": report["cross_reference_summary"]}, ensure_ascii=False))
if __name__ == "__main__":
    main()
