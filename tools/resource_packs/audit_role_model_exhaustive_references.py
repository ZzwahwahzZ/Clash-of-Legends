#!/usr/bin/env python3
"""Exhaustive provenance-preserving search for unresolved character role assets."""
from __future__ import annotations
import configparser, hashlib, json, re
from pathlib import Path

ROOT=Path.cwd()
RESOURCE=ROOT/"resource_stage"
CATALOG=RESOURCE/"world/resource_mappings/role_model_candidate_catalog.json"
OUT=ROOT/"reports/role-model-exhaustive-reference-audit.json"
TEXT_EXT={".ini",".xml",".json",".txt",".cfg",".csv",".dat",".js",".lua",".fui",".scene",".tres",".res",".tscn"}
MAX_TEXT=8*1024*1024
TOKENS=set()
for i in range(9998800,9998872,10):
    TOKENS.add(str(i))
for i in range(20001,20009):
    TOKENS.add(str(i))
CLASS_TERMS=("Taoist","Warrior","Trojan","Archer","Ninja","Monk","Pirate","Dragon","Windwalker","Thunderstriker")
def decode(raw):
    for enc in ("utf-8-sig","gb18030","utf-16","cp1252"):
        try:return raw.decode(enc),enc
        except (UnicodeDecodeError,LookupError):pass
    return None,None
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    cat=json.loads(CATALOG.read_text(encoding="utf-8"))
    for row in cat.get("role_simple_object_candidates",[]):
        TOKENS.add(str(row["simple_object_id"]))
        for part in row.get("simple_object",{}).get("parts",[]):
            for k in ("part_id","texture_id"):
                if part.get(k):TOKENS.add(str(part[k]))
    hits=[]; path_hits=[]; scanned=0; undecodable=[]; size_skips=0
    for p in sorted(RESOURCE.rglob("*")):
        if not p.is_file():continue
        rel=p.relative_to(ROOT).as_posix()
        name=p.name.lower()
        for token in TOKENS:
            if re.search(rf"(?<![0-9]){re.escape(token)}(?![0-9])",name):
                path_hits.append({"token":token,"path":rel,"kind":"filename"})
        if p.suffix.lower() not in TEXT_EXT:continue
        try:
            if p.stat().st_size>MAX_TEXT:size_skips+=1;continue
            raw=p.read_bytes()
        except OSError:continue
        text,enc=decode(raw)
        if text is None:
            undecodable.append(rel);continue
        scanned+=1
        for line_no,line in enumerate(text.splitlines(),1):
            matched=[t for t in TOKENS if re.search(rf"(?<![0-9]){re.escape(t)}(?![0-9])",line)]
            if matched:
                hits.append({"path":rel,"line":line_no,"encoding":enc,"tokens":matched,"context":line.strip()[:700]})
            if any(term.lower() in line.lower() for term in CLASS_TERMS):
                if p.name.lower() in {"rolechoose.ini","rolechoose_js.ini","selectcharacter.ini","3dsimplerole.ini"}:
                    hits.append({"path":rel,"line":line_no,"encoding":enc,"tokens":[],"context":line.strip()[:700],"kind":"class_registry_line"})
    # Exact source identity joins are preserved as evidence, never upgraded to a verified visual mapping.
    js=cat.get("rolechoose_js_source_role_joins",[])
    out={
      "schema_version":"1.0.0",
      "purpose":"Locate original character model/texture references outside the narrow DBC join.",
      "source_client":cat.get("source_client"),
      "external_parser_reference":{"name":"C3Studio","url":"https://github.com/abdouthematrix/C3Studio","role":"Independent C3/INI parser and viewport reference for follow-up validation","execution_status":"NOT_EXECUTED_IN_THIS_CI; source inspected as an external tool candidate"},
      "scan":{"resource_files_total":sum(1 for p in RESOURCE.rglob("*") if p.is_file()),"text_files_scanned":scanned,"oversize_text_files_skipped":size_skips,"undecodable_text_files":undecodable},
      "searched_tokens":sorted(TOKENS),
      "filename_hits":path_hits,
      "content_hits":hits,
      "source_class_gender_simple_role_joins":js,
      "unresolved_part_ids":[{"role":r["source_section"],"simple_object_id":r["simple_object_id"],"part_id":p["part_id"],"texture_id":p["texture_id"]} for r in cat.get("role_simple_object_candidates",[]) for p in r.get("simple_object",{}).get("parts",[]) if not p.get("object_resolved") or not p.get("texture_resolved")],
      "conclusion":"DISCOVERY_ONLY; no class/gender model mapping is approved without exact source identity, resolved mesh+texture, and visual/runtime validation."
    }
    OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"text_files_scanned":scanned,"filename_hits":len(path_hits),"content_hits":len(hits),"unresolved_parts":len(out["unresolved_part_ids"]),"class_gender_source_joins":len(js)},ensure_ascii=False))
if __name__=="__main__":main()
