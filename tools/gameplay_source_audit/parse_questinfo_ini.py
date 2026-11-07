#!/usr/bin/env python3
"""Read-only structural parser for Conquer Mobile questinfo INI variants.

Raw names, dialogue, objective descriptions and reward text are deliberately omitted.
The report preserves source IDs, category/level metadata, NPC locators, prerequisites,
objective tag types and cross-language structural differences.
"""
from __future__ import annotations
import argparse, collections, hashlib, json, re, zipfile
from pathlib import Path

LANG_PATHS = {
    "en": "assets/ConquerRes/ini/questinfo.ini",
    "ar": "assets/ConquerRes/ini_ar/questinfo.ini",
    "es": "assets/ConquerRes/ini_sp/questinfo.ini",
}
ALT_PATHS = {
    "passion_server": "assets/ConquerRes/ini/questinfopassionserver.ini",
    "nontrade": "assets/ConquerRes/ini/Questinfo_nontrade.ini",
}
TAG_RE = re.compile(r"\[([A-Za-z_]+)(?:\s+([^\]]*))?\]")
INTENTION_RE = re.compile(r"Intention\d+\Z")
TASK_PATH_RE = re.compile(r"(quest|task|mission|copy_trace|dailyactivity|activitytask|process_task)", re.I)

def parse_ini(raw: bytes):
    text = raw.decode("utf-8-sig").replace("\r", "")
    chunks = re.split(r"(?m)^\[([^\]]+)\]\s*$", text)
    sections, duplicate_keys = {}, []
    for i in range(1, len(chunks), 2):
        section, fields = chunks[i].strip(), {}
        for line_no, line in enumerate(chunks[i + 1].split("\n"), 1):
            line = line.strip()
            if not line or line.startswith(";") or line.startswith("//") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key, value = key.strip(), value.strip()
            if key in fields:
                duplicate_keys.append({"section": section, "key": key, "line_in_section": line_no})
            fields[key] = value
        sections[section] = fields
    return sections, duplicate_keys

def parse_npc_locator(value):
    if not value:
        return None
    parts = value.split(",")
    if len(parts) < 6:
        return {"raw_field_count": len(parts), "parse_status": "unparsed"}
    return {"npc_id": parts[0], "map_id": parts[1], "x": parts[2], "y": parts[3],
            "npc_key": parts[4], "map_name": ",".join(parts[5:])}

def analyze_catalogue(lang, path, raw, include_index=False):
    sections, duplicate_keys = parse_ini(raw)
    records = [{"section": section, **fields} for section, fields in sections.items() if section.isdigit()]
    type_cfg = sections.get("TaskType", {})
    type_names = {}
    for i in range(1, int(type_cfg.get("Num", "0") or 0) + 1):
        tid = type_cfg.get(f"TypeId{i}")
        if tid is not None:
            type_names[tid] = type_cfg.get(f"TypeName{i}", "")
    type_counts = collections.Counter(r.get("TypeId", "<missing>") for r in records)
    big_type_counts = collections.Counter(r.get("BigTypeId", "<missing>") for r in records)
    mission_sections = collections.defaultdict(list)
    for r in records:
        mission_sections[r.get("MissionId", "<missing>")].append(r["section"])
    duplicate_ids = {k: v for k, v in mission_sections.items() if len(v) > 1}
    field_counts = collections.Counter(k for r in records for k in r if k != "section")
    intention_count_dist, objective_tag_counts = collections.Counter(), collections.Counter()
    type_summary, index = [], []
    for r in records:
        intention_fields = [(k, v) for k, v in r.items() if INTENTION_RE.fullmatch(k)]
        intention_count_dist[len(intention_fields)] += 1
        tags = []
        for _, value in intention_fields:
            tags.extend(m.group(1).lower() for m in TAG_RE.finditer(value))
        objective_tag_counts.update(tags)
        if include_index:
            pre = [x for x in re.split(r"[|,]", r.get("Prequest", "")) if x and x != "0"]
            index.append({
                "section": r["section"], "mission_id": r.get("MissionId"),
                "type_id": r.get("TypeId"), "big_type_id": r.get("BigTypeId"),
                "level_min": r.get("Lv_min"), "level_max": r.get("Lv_max"),
                "prerequisite_ids": pre,
                "begin_npc": parse_npc_locator(r.get("BeginNpcId")),
                "finish_npc": parse_npc_locator(r.get("FinishNpcId")),
                "map_field": r.get("Map"), "objective_count": len(intention_fields),
                "objective_tags": sorted(set(tags)),
                "activity_begin": r.get("ActivityBeginTime"), "activity_end": r.get("ActivityEndTime"),
                "has_prize": bool(r.get("Prize")), "has_action_base": bool(r.get("ActionBase")),
                "has_auto_lua_command": bool(r.get("AutoLuaCmd")),
                "has_server_limit": bool(r.get("ServerLimit")),
                "has_cross_npc_id": bool(r.get("CrossNpcId")),
                "has_trace_limit": bool(r.get("TraceLimit")),
                "personal_npc_count": sum(1 for k in r if re.fullmatch(r"PersonalNpcId\d+", k)),
            })
    for tid, count in sorted(type_counts.items(), key=lambda x: (0, int(x[0])) if x[0].isdigit() else (1, x[0])):
        subset = [r for r in records if r.get("TypeId", "<missing>") == tid]
        levels = []
        for r in subset:
            try:
                levels.append((int(r.get("Lv_min", "0") or 0), int(r.get("Lv_max", "0") or 0)))
            except ValueError:
                pass
        type_summary.append({
            "type_id": tid, "type_name": type_names.get(tid, ""), "records": count,
            "unique_mission_ids": len({r.get("MissionId") for r in subset}),
            "level_min": min((x[0] for x in levels), default=None),
            "level_max": max((x[1] for x in levels), default=None),
            "with_begin_npc": sum(bool(r.get("BeginNpcId")) for r in subset),
            "with_finish_npc": sum(bool(r.get("FinishNpcId")) for r in subset),
            "with_prerequisite": sum(bool(r.get("Prequest") not in (None, "", "0")) for r in subset),
            "with_objectives": sum(any(INTENTION_RE.fullmatch(k) for k in r) for r in subset),
        })
    summary = {
        "language": lang, "source_path": path, "source_sha256": hashlib.sha256(raw).hexdigest(),
        "source_bytes": len(raw),
        "declared_total_mission": int(sections.get("TotalMission", {}).get("TotalMission", "0") or 0),
        "numeric_record_sections": len(records),
        "unique_mission_ids": len({r.get("MissionId") for r in records}),
        "duplicate_mission_ids": duplicate_ids, "duplicate_key_count": len(duplicate_keys),
        "type_definitions": type_names, "type_counts": type_summary,
        "big_type_counts": dict(big_type_counts), "field_presence_counts": dict(sorted(field_counts.items())),
        "objective_count_distribution": dict(sorted(intention_count_dist.items())),
        "objective_tag_counts": dict(sorted(objective_tag_counts.items())),
        "records_with_begin_npc": sum(bool(r.get("BeginNpcId")) for r in records),
        "records_with_finish_npc": sum(bool(r.get("FinishNpcId")) for r in records),
        "records_with_prerequisite": sum(bool(r.get("Prequest") not in (None, "", "0")) for r in records),
        "records_with_map_field": sum(bool(r.get("Map") not in (None, "", "0")) for r in records),
        "records_with_auto_lua_command": sum(bool(r.get("AutoLuaCmd")) for r in records),
        "records_without_objectives": sum(not any(INTENTION_RE.fullmatch(k) for k in r) for r in records),
        "duplicate_keys": duplicate_keys[:100],
    }
    if include_index:
        summary["record_index"] = index
    return summary, {r.get("MissionId") for r in records}

def main():
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--apk", type=Path)
    src.add_argument("--candidate-zip", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--include-record-index", action="store_true")
    args = ap.parse_args()
    archive, prefix = args.apk or args.candidate_zip, ("apk_0/" if args.candidate_zip else "")
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        def find(path):
            exact = prefix + path
            if exact in names:
                return exact
            matches = [n for n in names if n.endswith("/" + path)]
            return matches[0] if matches else None
        results, id_sets = {}, {}
        for lang, rel in LANG_PATHS.items():
            member = find(rel)
            if not member:
                results[lang] = {"status": "missing", "expected_path": rel}
                continue
            results[lang], id_sets[lang] = analyze_catalogue(
                lang, member, z.read(member), include_index=(lang == "en" and args.include_record_index))
        alternates = {}
        for label, rel in ALT_PATHS.items():
            member = find(rel)
            if not member:
                alternates[label] = {"status": "not_present_in_this_apk", "expected_path": rel}
                continue
            alternates[label], _ = analyze_catalogue(label, member, z.read(member), include_index=False)
        comparisons = {}
        for a, b in [("en", "ar"), ("en", "es"), ("ar", "es")]:
            if a in id_sets and b in id_sets:
                comparisons[f"{a}_vs_{b}"] = {
                    "only_a_count": len(id_sets[a] - id_sets[b]),
                    "only_b_count": len(id_sets[b] - id_sets[a]),
                    "common_ids": len(id_sets[a] & id_sets[b])}
        related = []
        for name in names:
            if not TASK_PATH_RE.search(name) or name.endswith("/"):
                continue
            info = z.getinfo(name)
            if info.file_size > 32 * 1024 * 1024:
                continue
            if name.endswith((".ini", ".dat", ".lua", ".xml", ".json", ".txt", ".dex", ".so")):
                related.append({"path": name, "size_bytes": info.file_size})
    report = {
        "schema_version": "1.0.0", "source_apk": archive.name,
        "analysis": "Structural quest catalogue extraction; raw names, dialogue, objective text and reward text are intentionally omitted",
        "catalogues": results, "alternate_catalogues": alternates,
        "language_id_comparisons": comparisons, "related_task_files": related,
        "scope_notes": [
            "EN, AR and ES questinfo.ini files are separate resources with different MissionId sets and counts; do not merge them as synchronized translations.",
            "questinfopassionserver.ini is reported separately as an alternate server catalogue and is not merged into the standard questinfo.ini catalogue.",
            "A record count is not a count of currently available/live quests; availability, prerequisites, server flags, event windows and task state must be evaluated.",
            "NPC locators are source references only; they are not proof that a destination is reachable or that the NPC belongs to a specific world map without cross-checking world/NPC data.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output),
        "catalogues": {k: {"records": v.get("numeric_record_sections"), "unique_ids": v.get("unique_mission_ids")} for k, v in results.items()},
        "alternates": {k: v.get("numeric_record_sections") for k, v in alternates.items()},
        "related_file_count": len(related)}, ensure_ascii=False), flush=True)
    if results.get("en", {}).get("numeric_record_sections", 0) == 0:
        raise SystemExit("Primary English questinfo.ini not found or empty")

if __name__ == "__main__":
    main()
