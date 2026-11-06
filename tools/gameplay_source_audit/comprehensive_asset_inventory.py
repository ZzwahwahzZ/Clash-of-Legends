#!/usr/bin/env python3
"""Comprehensive, content-first inventory for the exact-version Mobile asset bundle.

Every outer ZIP member and every member of nested ZIP/APK files is recorded.
PolyFile's magic matcher is used on content bytes, never on extensions alone.
No proprietary/unknown binary field is assigned an invented schema.
"""
from __future__ import annotations
import argparse, hashlib, json, math, re, subprocess, tempfile, zipfile
from collections import Counter
from pathlib import Path, PurePosixPath

try:
    from polyfile.magic import MagicMatcher
    MATCHER = MagicMatcher.DEFAULT_INSTANCE
    POLYFILE_IMPORT_ERROR = None
except Exception as exc:  # retain a complete inventory even if matcher setup fails
    MATCHER = None
    POLYFILE_IMPORT_ERROR = f"{type(exc).__name__}: {exc}"

CHUNK = 1024 * 1024
MAX_MATCH_BYTES = 16 * 1024 * 1024
TEXT_SAMPLE = 256 * 1024
INTEREST = re.compile(r"(skill|magic|motion|action|anim|walk|run|stand|idle|attack|defen|role|weapon|mount|effect|3d|c3|ani|dbc|wdb)", re.I)

def sha256_stream(stream):
    h=hashlib.sha256()
    while True:
        b=stream.read(CHUNK)
        if not b: break
        h.update(b)
    return h.hexdigest()

def entropy(data):
    if not data: return 0.0
    counts=Counter(data); n=len(data)
    return round(-sum((v/n)*math.log2(v/n) for v in counts.values()),4)

def magic_matches(data):
    if MATCHER is None: return []
    try:
        out=[]
        for m in MATCHER.match(data):
            out.append({"mimetypes":list(getattr(m,"mimetypes",[]) or []),"description":str(m)[:500]})
        return out
    except Exception as exc:
        return [{"error":f"{type(exc).__name__}: {exc}"}]

def record(name, size, data, digest, container, depth):
    sample=data[:TEXT_SAMPLE]
    printable=sum(1 for b in sample if b in (9,10,13) or 32<=b<=126 or b>=0xC0)
    ratio=round(printable/len(sample),4) if sample else 0.0
    low=name.lower()
    return {
        "container":container,"path":name,"depth":depth,"size_bytes":size,
        "extension":PurePosixPath(name).suffix.lower(),"sha256":digest,
        "content_magic":magic_matches(data[:MAX_MATCH_BYTES]),
        "sample_entropy":entropy(data[:MAX_MATCH_BYTES]),
        "sample_printable_ratio":ratio,
        "text_candidate":ratio>=0.78,
        "path_relevance":bool(INTEREST.search(low)),
        "review_priority":"HIGH" if INTEREST.search(low) else ("UNKNOWN_BINARY" if ratio<0.35 and size else "GENERAL")
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",type=Path)
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--polyfile-report",type=Path,default=None)
    args=ap.parse_args()
    if not args.archive.is_file(): raise SystemExit(f"Archive not found: {args.archive}")
    rows=[]; nested_count=0; errors=[]
    with zipfile.ZipFile(args.archive) as outer:
        for info in outer.infolist():
            if info.is_dir(): continue
            try:
                data=outer.read(info)
                digest=hashlib.sha256(data).hexdigest()
                rows.append(record(info.filename,info.file_size,data,digest,args.archive.name,0))
                if info.filename.lower().endswith((".apk",".zip",".jar")):
                    nested_count+=1
                    try:
                        import io
                        with zipfile.ZipFile(io.BytesIO(data)) as inner:
                            for item in inner.infolist():
                                if item.is_dir(): continue
                                try:
                                    blob=inner.read(item)
                                    rows.append(record(item.filename,item.file_size,blob,hashlib.sha256(blob).hexdigest(),info.filename,1))
                                except Exception as exc:
                                    errors.append({"container":info.filename,"path":item.filename,"error":f"{type(exc).__name__}: {exc}"})
                    except zipfile.BadZipFile:
                        pass
            except Exception as exc:
                errors.append({"container":args.archive.name,"path":info.filename,"error":f"{type(exc).__name__}: {exc}"})
    # Run PolyFile against each nested APK/ZIP as a whole so its recursive parsers can
    # map ZIP members and supported embedded structures. Raw output is preserved.
    poly_reports=[]
    if args.polyfile_report:
        args.polyfile_report.parent.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(args.archive) as outer, tempfile.TemporaryDirectory(prefix="polyfile-mobile-") as td:
            for i,info in enumerate(outer.infolist()):
                if info.is_dir() or not info.filename.lower().endswith((".apk",".zip")): continue
                target=Path(td)/f"nested-{i}{Path(info.filename).suffix.lower()}"
                target.write_bytes(outer.read(info))
                try:
                    proc=subprocess.run(["polyfile","--format","sbud","--no-contents",str(target)],
                        capture_output=True,text=True,timeout=900,check=False)
                    outpath=args.polyfile_report.with_name(args.polyfile_report.stem+f"-{i}.json")
                    outpath.write_text(proc.stdout or "",encoding="utf-8")
                    poly_reports.append({"source_member":info.filename,"exit_code":proc.returncode,
                        "report_file":outpath.name,"stderr_tail":(proc.stderr or "")[-2000:]})
                except Exception as exc:
                    poly_reports.append({"source_member":info.filename,"error":f"{type(exc).__name__}: {exc}"})
    counts=Counter(r["extension"] or "[no extension]" for r in rows)
    payload={
      "schema_version":"2.0.0","scanner":"content-first inventory + Trail of Bits PolyFile",
      "source_archive":args.archive.name,"outer_member_count":sum(1 for x in zipfile.ZipFile(args.archive).infolist() if not x.is_dir()),
      "nested_archive_count":nested_count,"total_inventory_records":len(rows),
      "extension_counts":dict(sorted(counts.items())),
      "high_priority_count":sum(1 for r in rows if r["review_priority"]=="HIGH"),
      "unknown_binary_count":sum(1 for r in rows if r["review_priority"]=="UNKNOWN_BINARY"),
      "polyfile_available":MATCHER is not None,"polyfile_import_error":POLYFILE_IMPORT_ERROR,
      "polyfile_recursive_reports":poly_reports,"read_errors":errors,
      "coverage_policy":"Every regular outer archive member and every regular member of each nested ZIP/APK is listed. Unsupported or unknown data is retained as UNKNOWN_BINARY; this is an inventory, not a guarantee that every proprietary embedded format is decoded.",
      "files":rows
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in payload.items() if k not in ("files","polyfile_recursive_reports")},ensure_ascii=False))
if __name__=="__main__": main()
