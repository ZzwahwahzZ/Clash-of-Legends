#!/usr/bin/env python3
"""Content-first recursive inventory for the version-matched Mobile asset bundle."""
from __future__ import annotations
import argparse, hashlib, json, math, re, subprocess, tempfile, zipfile
from collections import Counter
from pathlib import Path, PurePosixPath

try:
    from polyfile.magic import MagicMatcher
    MATCHER=MagicMatcher.DEFAULT_INSTANCE
    MATCHER_ERROR=None
except Exception as exc:
    MATCHER=None
    MATCHER_ERROR=f"{type(exc).__name__}: {exc}"

CHUNK=1024*1024
MATCH_LIMIT=256*1024
SAMPLE_LIMIT=256*1024
INTEREST=re.compile(r"(skill|magic|motion|action|anim|walk|run|stand|idle|attack|defen|role|weapon|mount|effect|3d|c3|ani|dbc|wdb)",re.I)

def entropy(data):
    if not data: return 0.0
    counts=Counter(data); n=len(data)
    return round(-sum((v/n)*math.log2(v/n) for v in counts.values()),4)

def inspect_stream(stream,size,name,container,depth):
    digest=hashlib.sha256(); sample=bytearray(); match_sample=bytearray()
    while True:
        block=stream.read(CHUNK)
        if not block: break
        digest.update(block)
        if len(sample)<SAMPLE_LIMIT: sample.extend(block[:SAMPLE_LIMIT-len(sample)])
        if len(match_sample)<MATCH_LIMIT: match_sample.extend(block[:MATCH_LIMIT-len(match_sample)])
    raw=bytes(match_sample)
    matches=[]
    if MATCHER is not None:
        try:
            for m in MATCHER.match(raw):
                matches.append({"mimetypes":list(getattr(m,"mimetypes",[]) or []),"description":str(m)[:400]})
        except Exception as exc:
            matches.append({"error":f"{type(exc).__name__}: {exc}"})
    printable=sum(1 for b in sample if b in (9,10,13) or 32<=b<=126 or b>=0xC0)
    ratio=round(printable/len(sample),4) if sample else 0.0
    relevant=bool(INTEREST.search(name))
    return {"container":container,"path":name,"depth":depth,"size_bytes":size,
      "extension":PurePosixPath(name).suffix.lower(),"sha256":digest.hexdigest(),
      "content_magic":matches,"sample_entropy":entropy(raw),
      "sample_printable_ratio":ratio,"text_candidate":ratio>=0.78,
      "path_relevance":relevant,
      "review_priority":"HIGH" if relevant else ("UNKNOWN_BINARY" if ratio<0.35 and size else "GENERAL")}

def scan_zip(zf,container,depth,rows,errors,nested_files):
    if depth > 4:
        errors.append({"container":container,"path":"[nested archive]","error":"MAX_NESTED_ARCHIVE_DEPTH_EXCEEDED"})
        return
    for info in zf.infolist():
        if info.is_dir(): continue
        try:
            with zf.open(info) as stream:
                rows.append(inspect_stream(stream,info.file_size,info.filename,container,depth))
            if depth < 4 and info.filename.lower().endswith((".apk",".zip",".jar")):
                # PolyFile stage reopens members from the outer archive only.
                # Nested-archive ZipInfo objects belong to a different ZipFile.
                if depth == 0:
                    nested_files.append((info.filename,info))
                try:
                    with zf.open(info) as stream, tempfile.NamedTemporaryFile(prefix="nested-archive-",suffix=Path(info.filename).suffix,delete=True) as tmp:
                        while True:
                            block=stream.read(CHUNK)
                            if not block: break
                            tmp.write(block)
                        tmp.flush()
                        try:
                            with zipfile.ZipFile(tmp.name) as inner:
                                scan_zip(inner,container+"!"+info.filename,depth+1,rows,errors,nested_files)
                        except zipfile.BadZipFile:
                            pass
                except Exception as exc:
                    errors.append({"container":container,"path":info.filename,"error":f"{type(exc).__name__}: {exc}"})
        except Exception as exc:
            errors.append({"container":container,"path":info.filename,"error":f"{type(exc).__name__}: {exc}"})

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",type=Path)
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--polyfile-report",type=Path,default=None)
    args=ap.parse_args()
    if not args.archive.is_file(): raise SystemExit(f"Archive not found: {args.archive}")
    rows=[]; errors=[]; nested=[]
    with zipfile.ZipFile(args.archive) as outer:
        outer_count=sum(1 for x in outer.infolist() if not x.is_dir())
        scan_zip(outer,args.archive.name,0,rows,errors,nested)
    reports=[]
    if args.polyfile_report:
        args.polyfile_report.parent.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(args.archive) as outer, tempfile.TemporaryDirectory(prefix="polyfile-mobile-") as td:
            for i,(member,info) in enumerate(nested):
                if not member.lower().endswith((".apk",".zip")): continue
                target=Path(td)/f"nested-{i}{Path(member).suffix.lower()}"
                with outer.open(info) as src,target.open("wb") as dst:
                    while True:
                        block=src.read(CHUNK)
                        if not block: break
                        dst.write(block)
                try:
                    proc=subprocess.run(["polyfile","--format","sbud","--no-contents",str(target)],
                        capture_output=True,text=True,timeout=240,check=False)
                    outpath=args.polyfile_report.with_name(args.polyfile_report.stem+f"-{i}.json")
                    outpath.write_text(proc.stdout or "",encoding="utf-8")
                    reports.append({"source_member":member,"exit_code":proc.returncode,
                      "report_file":outpath.name,"stderr_tail":(proc.stderr or "")[-2000:]})
                except Exception as exc:
                    reports.append({"source_member":member,"error":f"{type(exc).__name__}: {exc}"})
    counts=Counter(r["extension"] or "[no extension]" for r in rows)
    payload={"schema_version":"2.2.0","scanner":"Trail of Bits PolyFile magic matcher + recursive archive inventory",
      "source_archive":args.archive.name,"outer_member_count":outer_count,
      "nested_archive_count":len(nested),"total_inventory_records":len(rows),
      "extension_counts":dict(sorted(counts.items())),
      "high_priority_count":sum(r["review_priority"]=="HIGH" for r in rows),
      "unknown_binary_count":sum(r["review_priority"]=="UNKNOWN_BINARY" for r in rows),
      "polyfile_available":MATCHER is not None,"polyfile_import_error":MATCHER_ERROR,
      "polyfile_recursive_reports":reports,"read_errors":errors,
      "coverage_policy":"Every regular outer ZIP member and every regular member of nested ZIP/APK/JAR archives is recorded recursively to depth 4. Full SHA-256 is streamed for every file; PolyFile content matching is bounded to the first 256 KiB to avoid excessive scan cost. Unknown binaries are retained; proprietary embedded formats still require dedicated parsers.",
      "files":rows}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in payload.items() if k not in ("files","polyfile_recursive_reports")},ensure_ascii=False))
if __name__=="__main__": main()
