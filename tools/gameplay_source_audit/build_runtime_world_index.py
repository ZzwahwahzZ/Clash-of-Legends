#!/usr/bin/env python3
"""Build a locale-aware runtime index from exact-version Mobile 1.1.2.3 source files."""
from __future__ import annotations
import argparse, hashlib, json, re, struct, subprocess, sys, tempfile
from collections import Counter
from pathlib import Path

def read(root: Path, rel: str):
    p = root / rel
    return p.read_bytes() if p.is_file() else None

def decode(data: bytes):
    for enc in ("utf-8-sig", "gb18030", "cp1252"):
        try: return data.decode(enc), enc
        except UnicodeDecodeError: pass
    return data.decode("utf-8", "replace"), "utf-8-replace"

def ini(root: Path, rel: str):
    data = read(root, rel)
    if data is None: return [], "missing"
    text, encoding = decode(data)
    rows, current = [], None
    for line_no, raw in enumerate(text.splitlines(), 1):
        line = raw.strip().lstrip("\ufeff")
        if not line or line.startswith((";", "#", "//")): continue
        if line.startswith("[") and "]" in line:
            current = {"section": line[1:line.index("]")], "line": line_no, "fields": {}}
            rows.append(current)
        elif "=" in line and current is not None:
            key, value = line.split("=", 1)
            current["fields"][key.strip()] = value.strip()
    return rows, encoding

def map_binary(data: bytes):
    if len(data) < 4: raise ValueError("gamemap.dat has no count header")
    count = struct.unpack_from("<I", data, 0)[0]
    if count > 100000: raise ValueError(f"invalid map count: {count}")
    off, rows = 4, []
    for index in range(count):
        if off + 8 > len(data): raise ValueError(f"truncated map record {index}")
        map_id, size = struct.unpack_from("<II", data, off); off += 8
        if size > 4096 or off + size + 4 > len(data): raise ValueError(f"invalid map path size at {index}")
        path = data[off:off + size].decode("utf-8"); off += size
        flags = struct.unpack_from("<I", data, off)[0]; off += 4
        rows.append({"map_id": map_id, "resource_path": path, "flags": flags, "record_index": index})
    if off != len(data): raise ValueError(f"{len(data)-off} trailing bytes in gamemap.dat")
    return rows

def npc_ref(value: str):
    if not value or value == "0": return None
    p = value.split(",")
    if len(p) < 4: return {"raw": value, "parse_status": "unrecognized"}
    try:
        return {"npc_id": int(p[0]), "npc_id_source": p[0], "map_id": int(p[1]),
                "x": int(p[2]), "y": int(p[3]), "name": p[4] if len(p)>4 else "",
                "place": p[5] if len(p)>5 else "", "raw": value, "parse_status": "parsed"}
    except ValueError:
        return {"raw": value, "parse_status": "unrecognized"}

def task(section):
    f = section["fields"]
    def number(k):
        try: return int(f[k])
        except (KeyError, ValueError): return None
    return {
        "source_section": section["section"], "mission_id": number("MissionId"),
        "name": f.get("Name", ""), "type_id": number("TypeId"), "big_type_id": number("BigTypeId"),
        "min_level": number("Lv_min"), "max_level": number("Lv_max"), "map_id": number("Map"),
        "prerequisite_ids": [int(x) for x in re.split(r"[|,]", f.get("Prequest", "")) if x.isdigit()],
        "profession_ids": [int(x) for x in f.get("Profession", "").split(",") if x.strip().isdigit()],
        "sex": number("Sex"), "activity_type": number("ActivityType"),
        "begin_npc": npc_ref(f.get("BeginNpcId", "")), "finish_npc": npc_ref(f.get("FinishNpcId", "")),
        "intent_amount": number("IntentAmount"),
        "intentions": [f[k] for k in sorted(f) if re.fullmatch(r"Intention\d+", k)],
        "intention_description": f.get("IntentionDesp", ""), "description": f.get("Content", ""),
        "reward_source": f.get("Prize", ""), "raw_fields": f,
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-dir", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--report", type=Path, required=True)
    a = ap.parse_args(); root = a.source_dir
    required = ["ini/gamemap.dat", "ini/gamemapex.ini", "ini/npc.ini", "ini/questinfo.ini", "ini_ar/questinfo.ini"]
    missing = [p for p in required if not (root/p).is_file()]
    if missing: raise SystemExit("Missing required world source: " + ", ".join(missing))

    maps = map_binary(read(root, "ini/gamemap.dat"))
    map_sections, map_enc = ini(root, "ini/gamemapex.ini")
    map_meta = {}
    for s in map_sections:
        if s["section"].isdigit(): map_meta[int(s["section"])] = s["fields"]
    for m in maps: m["map_meta"] = map_meta.get(m["map_id"], {}); m["name_en"] = m["map_meta"].get("Name", "")
    map_ids = {m["map_id"] for m in maps}
    extra_maps = [{"map_id": mid, "name_en": f.get("Name", ""), "map_meta": f, "metadata_only": True}
                  for mid, f in sorted(map_meta.items()) if mid not in map_ids]
    map_ids_without_metadata = sorted(map_id for map_id in map_ids if map_id not in map_meta)

    npc_sections, npc_enc = ini(root, "ini/npc.ini")
    npc_templates = [{"source_section": s["section"], "fields": s["fields"]} for s in npc_sections]
    npc_model_sections, npc_model_enc = ini(root, "ini/npcx.ini")
    npc_model_templates = [{"source_section": s["section"], "model_id": int(s["section"]) if s["section"].isdigit() else None,
                            "fields": s["fields"]} for s in npc_model_sections]
    class_selection = {}
    class_encodings = {}
    for locale, rel in [("en", "ini/selectcharacter.ini"), ("ar", "ini_ar/selectcharacter.ini"), ("sp", "ini_sp/selectcharacter.ini")]:
        sections, encoding = ini(root, rel)
        class_encodings[locale] = encoding
        class_selection[locale] = [{"source_section": s["section"], "fields": s["fields"]} for s in sections]
    en_sections, en_enc = ini(root, "ini/questinfo.ini")
    ar_sections, ar_enc = ini(root, "ini_ar/questinfo.ini")
    en_tasks = [s for s in en_sections if s["section"].isdigit() and "MissionId" in s["fields"]]
    ar_tasks = [s for s in ar_sections if s["section"].isdigit() and "MissionId" in s["fields"]]
    ar_by_section = {s["section"]: s["fields"] for s in ar_tasks}
    tasks = []
    for s in en_tasks:
        row = task(s); ar = ar_by_section.get(s["section"], {})
        row.update({"name_ar": ar.get("Name", ""), "description_ar": ar.get("Content", ""),
                    "intention_description_ar": ar.get("IntentionDesp", ""),
                    "intentions_ar": [ar[k] for k in sorted(ar) if re.fullmatch(r"Intention\d+", k)],
                    "raw_fields_ar": ar})
        tasks.append(row)
    en_sections_set = {s["section"] for s in en_tasks}
    for s in ar_tasks:
        if s["section"] not in en_sections_set:
            row = task(s); row.update({"name_ar": row["name"], "name": "",
                "description_ar": row["description"], "description": "",
                "intention_description_ar": row["intention_description"], "intentions_ar": row["intentions"],
                "raw_fields_ar": row["raw_fields"], "raw_fields": {}})
            tasks.append(row)

    quest_map_refs, npc_map_refs = Counter(), Counter()
    begin_count = finish_count = 0; missing_npc_maps = set()
    for q in tasks:
        if q["map_id"] not in (None, 0): quest_map_refs[q["map_id"]] += 1
        for k in ("begin_npc", "finish_npc"):
            ref = q[k]
            if ref and ref.get("parse_status") == "parsed":
                npc_map_refs[ref["map_id"]] += 1
                if k == "begin_npc": begin_count += 1
                else: finish_count += 1
                if ref["map_id"] not in map_ids: missing_npc_maps.add(ref["map_id"])

    duplicate_maps = sorted(mid for mid,n in Counter(m["map_id"] for m in maps).items() if n > 1)
    negative_npc_sentinels = sum(1 for q in tasks for k in ("begin_npc", "finish_npc")
                                 if q[k] and q[k].get("parse_status") == "parsed" and q[k].get("npc_id", 0) < 0)
    npc_map_ids_with_metadata_only = sorted(mid for mid in missing_npc_maps if mid in map_meta)
    npc_map_ids_without_any_catalog_metadata = sorted(mid for mid in missing_npc_maps if mid not in map_meta)
    duplicate_quests = sorted(mid for mid,n in Counter(q["mission_id"] for q in tasks if q["mission_id"] is not None).items() if n > 1)
    # Decrypt and parse the five exact-version Lua dialogue files before admitting
    # them into the runtime index. The parser validates decrypted signatures.
    with tempfile.TemporaryDirectory(prefix="world-dialogue-") as temp_dir:
        dialogue_output = Path(temp_dir) / "dialogues.json"
        dialogue_report_path = Path(temp_dir) / "dialogue-report.json"
        subprocess.run([
            sys.executable, str(Path(__file__).with_name("parse_dialogue_sources.py")),
            "--source-dir", str(root), "--output", str(dialogue_output),
            "--report", str(dialogue_report_path)
        ], check=True)
        dialogue_payload = json.loads(dialogue_output.read_text(encoding="utf-8"))
        dialogue_report = json.loads(dialogue_report_path.read_text(encoding="utf-8"))

    index = {"schema_version":"1.0.0", "source_version":"ConquerOnline-1.1.2.3",
        "source_policy":"Exact-version derived index. Encrypted dialogue files are admitted only after TQ cipher signature and Lua assignment validation.",
        "maps":maps, "map_metadata_without_binary_path":extra_maps,
        "npc_templates":npc_templates, "npc_model_templates":npc_model_templates,
        "class_selection":class_selection, "quests":tasks,
        "npc_dialogues":dialogue_payload["npc_dialogues"],
        "dialogue_texts":dialogue_payload["dialogue_texts"],
        "script_dialogue_texts":dialogue_payload["script_dialogue_texts"],
        "dialogue_sources":dialogue_payload["dialogue_sources"]}
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(index, ensure_ascii=False, separators=(",",":"))+"\n", encoding="utf-8")
    report = {"schema_version":"1.0.0","source_version":index["source_version"],
        "map_binary_records":len(maps),"unique_map_ids":len(map_ids),"duplicate_map_ids_preserved":duplicate_maps,
        "map_metadata_sections":len(map_meta),"map_metadata_without_binary_path":len(extra_maps),
        "map_binary_ids_without_metadata":map_ids_without_metadata,
        "npc_map_ids_with_metadata_only":npc_map_ids_with_metadata_only,
        "npc_map_ids_without_any_catalog_metadata":npc_map_ids_without_any_catalog_metadata,
        "negative_npc_id_sentinel_references":negative_npc_sentinels,
        "npc_template_sections":len(npc_templates),"npc_model_template_sections":len(npc_model_templates),
        "class_selection_sections":{k:len(v) for k,v in class_selection.items()},
        "english_quest_rows":len(en_tasks),
        "arabic_quest_rows":len(ar_tasks),"runtime_quest_rows":len(tasks),
        "duplicate_mission_ids_preserved_by_source_section":duplicate_quests,
        "tasks_with_begin_npc":begin_count,"tasks_with_finish_npc":finish_count,
        "quest_map_references":dict(sorted(quest_map_refs.items())),
        "npc_map_references":dict(sorted(npc_map_refs.items())),
        "npc_map_ids_missing_from_gamemap_dat":sorted(missing_npc_maps),
        "dialogue_parse":dialogue_report,
        "encodings":{"gamemapex":map_enc,"npc":npc_enc,"npcx":npc_model_enc,
            "quest_en":en_enc,"quest_ar":ar_enc,"class_selection":class_encodings},
        "output_bytes":a.output.stat().st_size,"validation":"SOURCE_INDEX_GENERATED_NOT_YET_RUNTIME_BEHAVIOR_VALIDATED"}
    a.report.parent.mkdir(parents=True, exist_ok=True)
    a.report.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == "__main__": main()
