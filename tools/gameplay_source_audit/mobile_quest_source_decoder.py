#!/usr/bin/env python3
"""Version-pinned quest resource decoder/auditor for Conquer Mobile 1.1.2.3.

This performs non-destructive format classification and TQ-cipher *candidate*
decoding only. It does not claim that a desktop cipher is the Android reader,
and it never emits runtime-ready quest records.
"""
from __future__ import annotations
import argparse, hashlib, json, re, tempfile, zipfile
from pathlib import Path

VERSION = "ConquerOnline-1.1.2.3"
ROOT = "assets/ConquerRes/"
SEEDS = (9527, 1234)

def sha(b: bytes) -> str: return hashlib.sha256(b).hexdigest()
def key_for(seed: int) -> bytes:
    state = seed & 0x7fffffff
    out = bytearray()
    for _ in range(128):
        state = (state * 214013 + 2531011) & 0x7fffffff
        out.append(((state >> 16) & 0x7fff) & 0xff)
    return bytes(out)
def decrypt_tq(data: bytes, seed: int) -> bytes:
    key = key_for(seed); out = bytearray(len(data))
    for i, value in enumerate(data):
        v = value ^ key[i & 127]; s = i & 7
        out[i] = v if not s else ((v >> s) | (v << (8-s))) & 255
    return bytes(out)
def signals(data: bytes) -> dict:
    sample = data[:min(len(data), 256*1024)]
    if not sample: return {"printable_ratio":0.0,"lua_signature":False,"ini_signature":False}
    printable = sum(x in (9,10,13) or 32 <= x <= 126 or x >= 0xc0 for x in sample)/len(sample)
    t = sample.decode("latin-1")
    return {"printable_ratio":round(printable,4),
            "lua_signature":bool(re.search(r"(?m)^\\s*(local\\s+\\w+|return\\s+\\w+)",t) or "ret.data" in t or "MainTask" in t),
            "ini_signature":bool(re.search(r"(?m)^\\s*\\[[^]\\r\\n]+\\]",t) and re.search(r"(?m)^\\s*[^;#\\r\\n][^=\\r\\n]*=",t))}
def classify(data: bytes) -> str:
    if data.startswith(b"\\x1f\\x8b"): return "GZIP"
    if data.startswith((b"PK\\x03\\x04",b"PK\\x05\\x06")): return "ZIP"
    if data.startswith(b"\\x1bLua"): return "LUA_BYTECODE"
    s=signals(data)
    if s["printable_ratio"] >= .88 and (s["lua_signature"] or s["ini_signature"]): return "PLAINTEXT_LUA_OR_INI_CANDIDATE"
    if s["printable_ratio"] >= .92: return "PLAINTEXT_TEXT_CANDIDATE"
    return "BINARY_OR_ENCRYPTED_UNCLASSIFIED"
def is_target(path: str) -> bool:
    p=path.lower()
    base=p.rsplit("/",1)[-1]
    return (base in {"questinfo.dat","taskitem_info.dat","mission.dat","process_task.dat","task_reward_type.dat","questinfo.ini","questinfopassionserver.ini","activitytask.ini"}
            or ("/client_realm_task/" in p and re.fullmatch(r"juqing\\d+\\.dat",base))
            or ("/script/" in p and re.fullmatch(r"clienttask\\d+\\.dat",base)))
def extract_candidate_records(data: bytes, role: str) -> dict:
    t=data.decode("latin-1")
    if role=="questinfo":
        ids=[int(x) for x in re.findall(r'\\["TaskID"\\]\\s*=\\s*(\\d+)',t)]
        fields={}
        for name in ("Goal","GoalPos","MapID","MapX","MapY","NpcID","ReachMapID","ReachMapX","ReachMapY","ReachNpcID","IntentionCount"):
            vals=re.findall(r'\\["'+name+r'"\\]\\s*=\\s*(-?\\d+)',t)
            if vals: fields[name]=[int(x) for x in vals]
        return {"task_ids":ids,"task_id_count":len(ids),"numeric_field_occurrences":fields}
    if role=="taskitem_info":
        ids=[int(x) for x in re.findall(r"itemtype\\d+\\s*=\\s*(\\d+)",t)]
        return {"item_type_ids":ids,"item_type_count":len(ids),
                "item_cd_values":[int(x) for x in re.findall(r"itemcd\\s*=\\s*(\\d+)",t)]}
    return {}
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",type=Path)
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--decoded-dir",type=Path,default=Path("build/mobile_quest_candidates"))
    a=ap.parse_args()
    if not a.archive.is_file(): raise SystemExit(f"archive not found: {a.archive}")
    records=[]; decoded=[]; apk_names=[]
    with zipfile.ZipFile(a.archive) as outer, tempfile.TemporaryDirectory(prefix="quest-apk-") as td:
        apk_candidates=[n for n in outer.namelist() if VERSION in n and n.lower().endswith(".apk")]
        if not apk_candidates: raise SystemExit("Exact-version Android APK not found in source archive")
        for apk_name in apk_candidates:
            apk_path=Path(td)/f"{len(apk_names)}.apk"
            with outer.open(apk_name) as src, apk_path.open("wb") as dst:
                while True:
                    b=src.read(1024*1024)
                    if not b: break
                    dst.write(b)
            apk_names.append(apk_name)
            with zipfile.ZipFile(apk_path) as apk:
                for member in apk.namelist():
                    if not member.startswith(ROOT) or not is_target(member): continue
                    raw=apk.read(member); rel=member[len(ROOT):]
                    row={"apk_member":apk_name+"!"+member,"relative_path":rel,"size_bytes":len(raw),"sha256":sha(raw),"raw_classification":classify(raw),"raw_signals":signals(raw)}
                    role="questinfo" if rel.lower().endswith("/questinfo.dat") or rel.lower()=="ini/luacfg/questinfo.dat" else ("taskitem_info" if rel.lower().endswith("taskitem_info.dat") else "other")
                    if role in ("questinfo","taskitem_info"):
                        row["cipher_candidates"]=[]
                        for seed in SEEDS:
                            candidate=decrypt_tq(raw,seed); sig=signals(candidate)
                            structurally_plausible=sig["lua_signature"] and sig["printable_ratio"]>=.85
                            cand={"cipher":"TQ_FILE_CIPHER_CANDIDATE","seed":seed,"signals":sig,"structure_candidate":structurally_plausible}
                            if structurally_plausible:
                                cand.update(extract_candidate_records(candidate,role))
                                locale="ar" if "/ini_ar/" in "/"+rel.lower() else ("sp" if "/ini_sp/" in "/"+rel.lower() else "default")
                                out=a.decoded_dir/role/locale/(Path(rel).stem+f"_seed_{seed}.lua")
                                out.parent.mkdir(parents=True,exist_ok=True); out.write_bytes(candidate)
                                cand["candidate_output"]=str(out); cand["candidate_sha256"]=sha(candidate)
                            row["cipher_candidates"].append(cand)
                    records.append(row)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    payload={"schema_version":"1.0.0","source_client":VERSION,"apk_members":apk_names,"files_found":len(records),"records":records,
      "acceptance_policy":"All TQ decryptions remain candidates until independently matched to the exact Android 1.1.2.3 reader/schema. No guessed PC format, field, ID join or candidate is approved for runtime."}
    a.output.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\\n",encoding="utf-8")
    print(json.dumps({"source_client":VERSION,"files_found":len(records),"by_raw_classification":{k:sum(x["raw_classification"]==k for x in records) for k in sorted({x["raw_classification"] for x in records})},"decoded_candidates":sum(len(x.get("cipher_candidates",[])) for x in records)},ensure_ascii=False))
if __name__=="__main__": main()
