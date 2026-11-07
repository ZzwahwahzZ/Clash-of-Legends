#!/usr/bin/env python3
"""Extract and audit quest/NPC/dialogue/action source candidates from the exact
Conquer Online Mobile 1.1.2.3 source archive. Discovery only: no undocumented
binary schema is decoded and no extracted proprietary source is committed.
"""
from __future__ import annotations
import argparse, hashlib, json, re, struct, tempfile, zipfile
from pathlib import Path, PurePosixPath

VERSION = "ConquerOnline-1.1.2.3"
TARGET_APKS = {"ConquerOnline/ConquerOnline-1.1.2.3.apk", "ConquerOnline/config.arm64_v8a.apk", "ConquerOnline/config.xxhdpi.apk", "ConquerOnline/install_time_1001.apk"}
ROOT_MARKER = "assets/ConquerRes/"
NAME_RE = re.compile(r"(quest|task|mission|npc|dialog|conversation|talk|objective|reward|script|action|story|event|guide|promotion|job)", re.I)
TEXT_EXTS = {".ini",".dat",".txt",".cfg",".xml",".json",".lua",".csv",".yaml",".yml",".properties",".bytes",".db",".sql"}
CODE_EXTS = {".dex",".so",".jar"}
TERMS = re.compile(rb"(quest|task|mission|npc|dialog|conversation|objective|reward|accept|complete|incomplete|turn.?in|script|cq_task|cq_action|taskid|questid)", re.I)
MAX_TEXT_SCAN = 16 * 1024 * 1024
MAX_EXTRACT = 128 * 1024 * 1024

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def dex_keyword_strings(data: bytes) -> list[dict]:
    hits=[]
    if len(data)<0x70 or data[:4] != b"dex\n": return hits
    try:
        count,=struct.unpack_from("<I",data,0x38)
        off,=struct.unpack_from("<I",data,0x3c)
        if count>2_000_000 or off+count*4>len(data): return hits
        for i in range(count):
            p,=struct.unpack_from("<I",data,off+i*4)
            if p>=len(data): continue
            q=p
            for _ in range(5):
                v=data[q]; q+=1
                if v<128: break
            end=data.find(b"\0",q)
            if end<0: continue
            raw=data[q:end]
            if TERMS.search(raw):
                value=raw.decode("utf-8","replace")
                hits.append({"string_id":i,"text":value[:320]})
                if len(hits)>=5000: break
    except (IndexError,struct.error): pass
    return hits

def binary_keyword_strings(data: bytes, limit=2000) -> list[dict]:
    out=[]
    for m in re.finditer(rb"[\x20-\x7e]{5,}",data):
        raw=m.group()
        if TERMS.search(raw):
            out.append({"byte_offset":m.start(),"text":raw.decode("latin-1","replace")[:320]})
            if len(out)>=limit: break
    return out

def safe_name(name: str) -> str:
    p=PurePosixPath(name.replace("\\","/"))
    return str(PurePosixPath(*(x for x in p.parts if x not in ("","/",".."))))

def scan_archive(z: zipfile.ZipFile, origin: str, output: zipfile.ZipFile,
                 report: dict, only_mobile_root: bool=False):
    for info in z.infolist():
        if info.is_dir(): continue
        raw_name=info.filename.replace("\\","/")
        if only_mobile_root and not raw_name.startswith(ROOT_MARKER) and not raw_name.startswith("res/") and Path(raw_name).suffix.lower() not in CODE_EXTS:
            continue
        base=Path(raw_name).name
        ext=Path(raw_name).suffix.lower()
        name_match=bool(NAME_RE.search(raw_name))
        code_file=ext in CODE_EXTS
        config_corpus_candidate = (ROOT_MARKER in raw_name and "/ini/" in raw_name and ext in TEXT_EXTS)
        if not name_match and not code_file and not config_corpus_candidate and ext not in TEXT_EXTS:
            continue
        if info.file_size > MAX_EXTRACT:
            if name_match or code_file:
                report["oversize_skipped"].append({"origin":origin,"path":raw_name,"size":info.file_size})
            continue
        try: data=z.read(info)
        except Exception as e:
            report["read_errors"].append({"origin":origin,"path":raw_name,"error":str(e)})
            continue
        text_hits=[]
        code_hits=[]
        if code_file:
            if ext==".dex": code_hits=dex_keyword_strings(data)
            else: code_hits=binary_keyword_strings(data)
        elif ext in TEXT_EXTS and len(data)<=MAX_TEXT_SCAN:
            for m in list(TERMS.finditer(data))[:250]:
                lo=max(0,m.start()-120); hi=min(len(data),m.end()+220)
                excerpt=data[lo:hi].decode("utf-8","replace").replace("\x00"," ")
                text_hits.append({"byte_offset":m.start(),"term":m.group().decode("latin-1"),"excerpt":excerpt[:420]})
        if not name_match and not code_file and not config_corpus_candidate and not text_hits:
            continue
        record={
            "origin":origin,"path":raw_name,"size_bytes":len(data),"sha256":digest(data),
            "extension":ext,"matched_filename":name_match,"config_corpus_candidate":config_corpus_candidate,
            "content_hit_count":len(text_hits),"code_string_hit_count":len(code_hits),
            "evidence":"PATH_CANDIDATE_ONLY" if name_match and not text_hits and not code_hits else ("INI_CONFIG_CORPUS_NEEDS_SEMANTIC_TRIAGE" if config_corpus_candidate and not text_hits and not code_hits else "PATH_OR_CONTENT_CANDIDATE_NEEDS_REVIEW")
        }
        if text_hits: record["content_hits"]=text_hits
        if code_hits: record["code_strings"]=code_hits
        report["candidates"].append(record)
        out_name=safe_name(f"{origin}/{raw_name}")
        if out_name in output.namelist():
            out_name=safe_name(f"{origin}/{digest(data)[:12]}_{base}")
        output.writestr(out_name,data)
        report["extracted_file_count"]+=1

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",type=Path)
    ap.add_argument("--output-dir",type=Path,default=Path("reports/quest-source-extraction"))
    ap.add_argument("--report",type=Path,default=Path("reports/quest-source-extraction.json"))
    args=ap.parse_args()
    if not args.archive.is_file(): raise SystemExit(f"Archive not found: {args.archive}")
    args.output_dir.mkdir(parents=True,exist_ok=True)
    args.report.parent.mkdir(parents=True,exist_ok=True)
    bundle=args.output_dir/"quest-source-candidates.zip"
    report={"tool":"quest_source_extractor.py","tool_version":"1.0.0","source_version":VERSION,
            "source_archive":args.archive.name,"source_archive_sha256":digest_file(args.archive),
            "policy":"Candidate extraction only. No proprietary source blobs are committed. No undocumented binary schema or task semantics are inferred.",
            "outer_member_count":0,"mobile_apk_candidates":[],"candidates":[],"oversize_skipped":[],"read_errors":[],"extracted_file_count":0}
    with zipfile.ZipFile(args.archive) as outer:
        report["outer_member_count"]=len(outer.infolist())
        report["expected_apk_paths"]=sorted(TARGET_APKS)
        outer_names=set(outer.namelist())
        apk_names=sorted(TARGET_APKS & outer_names)
        report["mobile_apk_candidates"]=[{"path":n,"size_bytes":outer.getinfo(n).file_size} for n in apk_names]
        report["missing_expected_apks"]=sorted(TARGET_APKS-outer_names)
        with zipfile.ZipFile(bundle,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
            # Search already-extracted, version-matched source members first.
            scan_archive(outer,"outer",output,report,only_mobile_root=False)
            with tempfile.TemporaryDirectory(prefix="mobile-quest-apk-") as td:
                for i,apk_name in enumerate(apk_names):
                    apk_path=Path(td)/f"client-{i}.apk"
                    with outer.open(apk_name) as src, apk_path.open("wb") as dst:
                        import shutil
                        shutil.copyfileobj(src,dst,1024*1024)
                    with zipfile.ZipFile(apk_path) as apk:
                        report.setdefault("apk_member_counts",[]).append({"apk":apk_name,"members":len(apk.infolist())})
                        scan_archive(apk,"apk_"+str(i),output,report,only_mobile_root=True)
            # Include a machine-readable manifest inside the extracted candidate bundle.
            output.writestr("EXTRACTION_MANIFEST.json",json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    report["candidate_count"]=len(report["candidates"])
    report["filename_match_count"]=sum(1 for x in report["candidates"] if x["matched_filename"])
    report["content_match_count"]=sum(1 for x in report["candidates"] if x["content_hit_count"] or x["code_string_hit_count"])
    report["output_bundle"]=str(bundle)
    report["output_bundle_size_bytes"]=bundle.stat().st_size
    args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    summary={k:report[k] for k in ("source_version","outer_member_count","mobile_apk_candidates","candidate_count","filename_match_count","content_match_count","extracted_file_count","output_bundle_size_bytes","oversize_skipped","read_errors","output_bundle")}
    print(json.dumps(summary,ensure_ascii=False))

def digest_file(path: Path) -> str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""): h.update(block)
    return h.hexdigest()

if __name__=="__main__": main()
