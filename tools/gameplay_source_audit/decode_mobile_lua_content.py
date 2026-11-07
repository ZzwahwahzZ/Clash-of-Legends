#!/usr/bin/env python3
"""Decode Mobile 1.1.2.3 Lua/config DAT candidates using evidence-led probes.

This tool preserves raw and decoded hashes. Seed 9527 outputs remain research
candidates until the exact Android reader implementation is independently proven.
"""
from __future__ import annotations
import argparse, hashlib, json, re
from pathlib import Path

SEEDS=(9527,1234)
MARKERS=(
    b"Dialog_Dialogue", b"NpcDialogueText_", b"SCRIPT_DIALOG_TEXT",
    b"local LuaSceneScript", b"local function", b"Questinfo_GetMainTask",
    b"local MainTask", b"TaskID", b"NpcID", b"ReachMapID",
    b"LuaScriptMgr_", b"NpcDialogueFunc", b"function ",
)

def sha(data): return hashlib.sha256(data).hexdigest()

def key_for(seed):
    state=seed & 0xffffffff
    out=bytearray()
    for _ in range(128):
        state=(state*0x343fd+0x269ec3)&0xffffffff
        out.append(((state>>16)&0x7fff)&0xff)
    return bytes(out)

def decrypt(data,seed):
    key=key_for(seed); out=bytearray(len(data))
    for i,b in enumerate(data):
        v=b^key[i&127]; shift=i&7
        out[i]=v if shift==0 else ((v>>shift)|(v<<(8-shift)))&255
    return bytes(out)

def probe(data):
    sample=data[:min(len(data),512*1024)]
    if not sample: return {"ascii_ratio":0.0,"markers":[]}
    ratio=sum(b in (9,10,13) or 32<=b<=126 for b in sample)/len(sample)
    markers=[m.decode("ascii") for m in MARKERS if m in sample]
    return {"ascii_ratio":round(ratio,4),"markers":markers}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("source_dir",type=Path)
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--decoded-dir",type=Path,required=True)
    args=ap.parse_args()
    rows=[]
    for path in sorted(args.source_dir.rglob("*.dat")):
        raw=path.read_bytes()
        for seed in SEEDS:
            dec=decrypt(raw,seed); sig=probe(dec)
            if not sig["markers"] or sig["ascii_ratio"]<0.30: continue
            rel=path.relative_to(args.source_dir)
            target=args.decoded_dir/str(seed)/rel.with_suffix(rel.suffix+".lua-candidate")
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(dec)
            text=dec.decode("utf-8",errors="replace")
            row={
                "source_path":str(rel),"source_size_bytes":len(raw),"source_sha256":sha(raw),
                "cipher_candidate":"TQ_FILE_CIPHER_RESEARCH_ONLY","seed":seed,
                "decoded_size_bytes":len(dec),"decoded_sha256":sha(dec),
                "signals":sig,"candidate_path":str(target),
            }
            if "npcdialogueinfo" in str(rel).lower():
                row["dialogue_ids"]=sorted({int(x) for x in re.findall(r"Dialog_Dialogue\\[(\\d+)\\]\\s*=",text)})
                row["dialogue_text_keys"]=sorted(set(re.findall(r'"(STR_[A-Za-z0-9_]+)"',text)))
                row["dialogue_type_counts"]={str(i):len(re.findall(r'\\["DlgType"\\]\\s*=\\s*'+str(i)+r'\\b',text)) for i in range(1,7)}
            if "npcdialoguetext_" in str(rel).lower():
                row["text_key_count"]=len(set(re.findall(r'NpcDialogueText_[A-Z]+\\["([^"]+)"\\]\\s*=',text)))
                row["task_text_key_count"]=len(set(re.findall(r'"(STR_TASK_\\d+)"',text)))
            if "luascriptmgr" in str(rel).lower():
                row["script_registry"]=[{"script_id":int(a),"file":b} for a,b in re.findall(r"\\[(\\d+)\\]\\s*=\\s*\\{\\s*file\\s*=\\s*[\\"']([^\\"']+)",text)]
            if "client_realm_task" in str(rel).lower():
                row["scene_function_names"]=re.findall(r"local function\\s+(\\w+)",text)
                row["scene_api_calls"]=sorted(set(re.findall(r"(LuaScriptMgr_\\w+)\\s*\\(",text)))
                row["view_positions"]=[{"x":int(x),"y":int(y)} for x,y in re.findall(r"LuaScriptMgr_SetViewPosByCell\\((\\d+)\\s*,\\s*(\\d+)\\)",text)]
            rows.append(row)
    report={
        "schema_version":"1.0.0","target":"Conquer Online Mobile 1.1.2.3",
        "policy":"All decoded files are research candidates; this does not establish the exact Android reader or approve runtime import.",
        "candidate_count":len(rows),"candidate_seed_counts":{str(seed):sum(r["seed"]==seed for r in rows) for seed in SEEDS},
        "candidates":rows,
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\\n",encoding="utf-8")
    print(json.dumps({"candidate_count":len(rows),"seed_counts":report["candidate_seed_counts"],
        "dialogue_id_count":sum(len(r.get("dialogue_ids",[])) for r in rows),
        "script_registry_count":sum(len(r.get("script_registry",[])) for r in rows),
        "scene_script_count":sum("client_realm_task" in r["source_path"] for r in rows)},ensure_ascii=False))
if __name__=="__main__": main()
