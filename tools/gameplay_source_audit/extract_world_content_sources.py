#!/usr/bin/env python3
"""Extract a bounded, exact-version source subset for private world-content analysis.

The output is a CI artifact, not a production runtime pack. It preserves the
original member paths and hashes and does not decrypt or reinterpret binary data.
"""
from __future__ import annotations
import argparse, hashlib, json, re, zipfile
from pathlib import Path, PurePosixPath
import tempfile

VERSION = "ConquerOnline-1.1.2.3"
ROOT = "assets/ConquerRes/"
EXACT = {
    "ini/gamemap.dat", "ini/gamemapex.ini", "ini/gamemaplayer.ini",
    "ini/npc.ini", "ini/npcex.ini", "ini/npcx.ini", "ini/slotnpc.ini", "ini/terrainnpc.ini",
    "ini/questinfo.ini", "ini/questinfopassionserver.ini",
    "ini/selectcharacter.ini", "ini_ar/selectcharacter.ini", "ini_sp/selectcharacter.ini",
    "ini/luacfg/questinfo.dat", "ini/luacfg/taskitem_info.dat",
    "ini_ar/luacfg/questinfo.dat", "ini_ar/luacfg/taskitem_info.dat",
    "ini_ar/questinfo.ini", "ini_ar/npc.ini", "ini_ar/npcx.ini", "ini_ar/terrainnpc.ini",
    "ini_sp/questinfo.ini", "ini_sp/npc.ini", "ini_sp/npcx.ini", "ini_sp/terrainnpc.ini",
    "ini/monster.dat", "ini/itemcfg.dat", "ini/copydrop.dat",
    # Real map archives referenced by the exact gamemap.dat catalog for the
    # current prototype's verified WindPlain, Desert, MapleForest, DragonPool,
    # and Market source-map entries.
    "map/map/newplain.7z", "map/map/desert.7z", "map/map/woods.7z",
    "map/map/dragon.7z", "map/map/street.7z",
    "script/dialogtext/scriptdialoguetext_ar.dat", "script/dialogtext/scriptdialoguetext_en.dat",
    "ini/luaui/publicfiles/otherconf/npcdialogueinfo.dat",
    "ini/luaui/publicfiles/wordfiles/npcdialoguetext.dat",
    "ini/luaui/publicfiles/wordfiles/npcdialoguetext_ar.dat",
    "ini/luaui/publicfiles/wordfiles/npcdialoguetext_en.dat",
    "ini/luaui/dialog/dlgnpcdialogue/dlgnpcdialogue.dat",
    "ini/luaui/dialog/dlgnpcdialogue/npcdialoguefunc.dat",
    "ini/luaui/dialog/dlgnpcdialogue/dlgmaintaskbook.dat",
    "ini/luaui/dialog/dlgnpcdialogue/dlgmaintaskletter.dat",
}
PATTERN = re.compile(r"(^|/)(client_realm_task/|clienttask[^/]*|[^/]*(quest|task|dialog|npc|juqing|gamemap)[^/]*\.(dat|ini)$)", re.I)
TEXT_EXTS = {".ini", ".txt", ".lua", ".json", ".xml", ".csv", ".dat"}

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def main() -> None:
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",type=Path)
    ap.add_argument("--output-dir",type=Path,required=True)
    ap.add_argument("--report",type=Path,required=True)
    args=ap.parse_args()
    out=args.output_dir
    out.mkdir(parents=True,exist_ok=True)
    extracted=[]; seen=set()
    with zipfile.ZipFile(args.archive) as outer, tempfile.TemporaryDirectory(prefix="world-content-apk-") as td:
        nested=[]
        for name in outer.namelist():
            if VERSION in name and name.lower().endswith(".apk"):
                target=Path(td)/f"{len(nested)}.apk"
                with outer.open(name) as src,target.open("wb") as dst:
                    while True:
                        block=src.read(1024*1024)
                        if not block: break
                        dst.write(block)
                nested.append((zipfile.ZipFile(target),name))
            elif VERSION in name and ROOT in name:
                rel=name.split(ROOT,1)[1].replace("\\","/")
                if rel.lower() in EXACT or PATTERN.search(rel):
                    data=outer.read(name)
                    key=(name,digest(data))
                    if key in seen: continue
                    seen.add(key)
                    target=out/PurePosixPath(rel)
                    target.parent.mkdir(parents=True,exist_ok=True)
                    target.write_bytes(data)
                    extracted.append({"source_member":name,"relative_path":rel,"output_path":str(target),"size_bytes":len(data),"sha256":digest(data)})
        for zf,outer_name in nested:
            for name in zf.namelist():
                if not name.startswith(ROOT): continue
                rel=name.split(ROOT,1)[1].replace("\\","/")
                if rel.lower() not in EXACT and not PATTERN.search(rel): continue
                data=zf.read(name)
                key=(outer_name+"!"+name,digest(data))
                if key in seen: continue
                seen.add(key)
                target=out/PurePosixPath(rel)
                target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes(data)
                extracted.append({"source_member":outer_name+"!"+name,"relative_path":rel,"output_path":str(target),"size_bytes":len(data),"sha256":digest(data)})
            zf.close()
    extracted.sort(key=lambda x:(x["relative_path"],x["source_member"]))
    payload={"schema_version":"1.0.0","source_version":VERSION,"source_archive":args.archive.name,"extracted_count":len(extracted),"files":extracted,"policy":"Exact source bytes for private inspection only; no decryptions, schema assumptions, or runtime approvals."}
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("WORLD CONTENT SOURCE SUBSET")
    print(json.dumps({"extracted_count":len(extracted),"by_extension":{ext:sum(1 for x in extracted if Path(x["relative_path"]).suffix.lower()==ext) for ext in sorted({Path(x["relative_path"]).suffix.lower() for x in extracted})}},ensure_ascii=False))
    for row in extracted: print(f'{row["relative_path"]} | {row["size_bytes"]} bytes | {row["sha256"]}')

if __name__=="__main__": main()
