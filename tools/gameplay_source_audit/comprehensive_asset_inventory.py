#!/usr/bin/env python3
"""Fast recursive inventory: complete paths/sizes, bounded samples, full hashes for code/data candidates."""
from __future__ import annotations
import argparse, hashlib, json, math, re, subprocess, tempfile, time, zipfile
from collections import Counter
from pathlib import Path, PurePosixPath

try:
    from polyfile.magic import MagicMatcher
    MATCHER = MagicMatcher.DEFAULT_INSTANCE
    MATCHER_ERROR = None
except Exception as exc:
    MATCHER = None
    MATCHER_ERROR = f"{type(exc).__name__}: {exc}"

CHUNK = 1024 * 1024
SAMPLE_LIMIT = 256 * 1024
INTEREST = re.compile(r"(quest|task|npc|dialog|talk|action|event|reward|item|skill|magic|motion|anim|walk|run|attack|role|weapon|\.dat$|\.ini$|\.xml$|\.json$|\.dex$|\.so$)", re.I)
FULL_HASH_EXT = {".dat", ".ini", ".xml", ".json", ".txt", ".csv", ".db", ".sqlite", ".dex", ".so", ".jar"}
ARCHIVE_EXT = (".apk", ".zip", ".jar")
def entropy(data):
    if not data: return 0.0
    counts = Counter(data); n = len(data)
    return round(-sum((v/n)*math.log2(v/n) for v in counts.values()), 4)
def sample_stream(stream):
    data = stream.read(SAMPLE_LIMIT)
    return data
def inspect_member(zf, info, container, depth, rows, errors, counter, started):
    name = info.filename
    ext = PurePosixPath(name).suffix.lower()
    relevant = bool(INTEREST.search(name))
    full_hash = relevant or ext in FULL_HASH_EXT or ext in ARCHIVE_EXT
    digest = hashlib.sha256() if full_hash else None
    sample = bytearray()
    try:
        with zf.open(info) as stream:
            if ext in ARCHIVE_EXT and depth < 4:
                with tempfile.NamedTemporaryFile(prefix="nested-", suffix=ext, delete=True) as tmp:
                    while True:
                        block = stream.read(CHUNK)
                        if not block: break
                        if digest: digest.update(block)
                        if len(sample) < SAMPLE_LIMIT: sample.extend(block[:SAMPLE_LIMIT-len(sample)])
                        tmp.write(block)
                    tmp.flush()
                    raw = bytes(sample)
                    rows.append(make_row(container, name, depth, info.file_size, ext, digest, raw, relevant))
                    counter[0] += 1
                    try:
                        with zipfile.ZipFile(tmp.name) as inner:
                            scan_zip(inner, container + "!" + name, depth + 1, rows, errors, counter, started)
                    except zipfile.BadZipFile:
                        pass
            else:
                raw = sample_stream(stream)
                sample.extend(raw)
                if digest:
                    digest.update(raw)
                    while True:
                        block = stream.read(CHUNK)
                        if not block: break
                        digest.update(block)
                rows.append(make_row(container, name, depth, info.file_size, ext, digest, bytes(sample), relevant))
                counter[0] += 1
        if counter[0] % 100 == 0:
            print(f"PROGRESS records={counter[0]} elapsed_seconds={int(time.time()-started)}", flush=True)
    except Exception as exc:
        errors.append({"container":container,"path":name,"error":f"{type(exc).__name__}: {exc}"})
def make_row(container, name, depth, size, ext, digest, sample, relevant):
    matches = []
    if MATCHER is not None:
        try:
            for m in MATCHER.match(sample):
                matches.append({"mimetypes":list(getattr(m,"mimetypes",[]) or []),"description":str(m)[:400]})
        except Exception as exc:
            matches.append({"error":f"{type(exc).__name__}: {exc}"})
    printable = sum(1 for b in sample if b in (9,10,13) or 32 <= b <= 126 or b >= 0xC0)
    ratio = round(printable/len(sample),4) if sample else 0.0
    return {"container":container,"path":name,"depth":depth,"size_bytes":size,"extension":ext,
      "sha256":digest.hexdigest() if digest else None,"hash_policy":"full" if digest else "sample_only",
      "content_magic":matches,"sample_entropy":entropy(sample),"sample_printable_ratio":ratio,
      "text_candidate":ratio>=0.78,"path_relevance":relevant,
      "review_priority":"HIGH" if relevant else ("UNKNOWN_BINARY" if ratio<0.35 and size else "GENERAL")}
def scan_zip(zf, container, depth, rows, errors, counter, started):
    if depth > 4:
        errors.append({"container":container,"path":"[nested archive]","error":"MAX_NESTED_ARCHIVE_DEPTH_EXCEEDED"})
        return
    infos = zf.infolist()
    print(f"ARCHIVE depth={depth} container={container} members={len(infos)}", flush=True)
    for info in infos:
        if not info.is_dir():
            inspect_member(zf, info, container, depth, rows, errors, counter, started)
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",type=Path)
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--polyfile-report",type=Path,default=None)
    args=ap.parse_args()
    if not args.archive.is_file(): raise SystemExit(f"Archive not found: {args.archive}")
    started=time.time(); rows=[]; errors=[]; counter=[0]
    with zipfile.ZipFile(args.archive) as outer:
        outer_count=sum(1 for x in outer.infolist() if not x.is_dir())
        scan_zip(outer,args.archive.name,0,rows,errors,counter,started)
    counts=Counter(r["extension"] or "[no extension]" for r in rows)
    payload={"schema_version":"2.3.0","scanner":"PolyFile bounded content sampling + recursive archive inventory",
      "source_archive":args.archive.name,"outer_member_count":outer_count,
      "total_inventory_records":len(rows),"extension_counts":dict(sorted(counts.items())),
      "high_priority_count":sum(r["review_priority"]=="HIGH" for r in rows),
      "unknown_binary_count":sum(r["review_priority"]=="UNKNOWN_BINARY" for r in rows),
      "full_hash_count":sum(r["hash_policy"]=="full" for r in rows),
      "sample_only_count":sum(r["hash_policy"]=="sample_only" for r in rows),
      "polyfile_available":MATCHER is not None,"polyfile_import_error":MATCHER_ERROR,
      "read_errors":errors,
      "coverage_policy":"Every regular member of the outer archive and nested APK/ZIP/JAR archives is inventoried recursively to depth 4 with path, size, extension, and bounded content magic. Full SHA-256 is computed for task/gameplay-relevant names, structured data, DEX/SO code, and nested archives; other large binary assets retain bounded sample fingerprints to avoid hashing hundreds of megabytes unnecessarily. Candidate extraction and APK decompilation are separate mandatory stages.",
      "elapsed_seconds":round(time.time()-started,2),"files":rows}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in payload.items() if k!="files"},ensure_ascii=False),flush=True)
if __name__=="__main__": main()
