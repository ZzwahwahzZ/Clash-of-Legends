#!/usr/bin/env python3
"""Extract NetDragon TPI/TPD resource containers into categorized game assets."""
import collections, csv, hashlib, json, re, struct, zipfile, zlib
from pathlib import Path

ROOT=Path.cwd()
STAGE=ROOT/"resource_stage"
REPORTS=ROOT/"reports"
INDEX_CSV=REPORTS/"resource-source-index.csv"
AUDIT_JSON=REPORTS/"source-archive-extension-audit.json"
CATALOG_JSON=STAGE/"world"/"resource_catalog.json"
MAX_ENTRY_BYTES=128*1024*1024

def safe_name(value):
    parts=[part for part in value.replace("\\","/").split("/") if part not in ("",".","..")]
    return "/".join(re.sub(r"[^A-Za-z0-9._-]+","_",part) for part in parts) or "unnamed.bin"

def classify(name):
    low=name.lower().replace("\\","/")
    ext=Path(low).suffix
    if ext in {".c3",".c3b",".c3a",".c3t",".c3i",".c3m",".c3p"} or low.startswith("c3/"):
        return "models"
    if ext in {".ogg",".wav",".mp3",".flac"} or any(x in low for x in ("audio/","sound/","music/","voice/")):
        return "audio"
    if any(x in low for x in ("fgui/","interface/","ui/","font/","icon/")) or ext in {".fui",".rgn"}:
        return "interface"
    if any(x in low for x in ("map/","terrain/","puzzle/","scene/")) or ext in {".dmap",".pux",".pul",".otherdata",".mjp",".pvr"}:
        return "maps"
    if any(x in low for x in ("monster/","mob/","creature/","boss/")):
        return "monsters"
    if any(x in low for x in ("role/","player/","character/","body/")):
        return "characters"
    if any(x in low for x in ("mount/","horse/","ride/","pet/")):
        return "mounts"
    if any(x in low for x in ("weapon/","armor/","armour/","equip/","item/")):
        return "equipment"
    if any(x in low for x in ("effect/","skill/","spell/","magic/","particle/")):
        return "effects"
    if ext in {".ani",".anim"} or "/ani/" in low:
        return "animations"
    return "world"

def read_c_string(data, offset):
    if offset<0 or offset>=len(data):
        raise ValueError("name offset outside TPI")
    end=data.find(b"\0",offset)
    if end<0:
        raise ValueError("unterminated TPI resource name")
    name=data[offset:end].decode("utf-8",errors="replace").strip()
    if not name:
        raise ValueError("empty TPI resource name")
    return name

if not INDEX_CSV.exists():
    raise SystemExit("resource-source-index.csv is missing; run prepare_assets.py first.")
rows=list(csv.DictReader(INDEX_CSV.open(encoding="utf-8")))
fields=["category","source_archive","source_path","staged_path","size_bytes","sha256"]
seen={row["sha256"] for row in rows}
pairs={}
for row in rows:
    inner=row["source_path"].split("!")[-1]
    ext=Path(inner).suffix.lower()
    if ext in {".tpi",".tpd"}:
        key=(row["source_archive"],row["source_path"][:-len(ext)].lower())
        pairs.setdefault(key,{})[ext]=row

results=[]
remove_paths=set()
new_rows=[]
index_zip=REPORTS/"tpi-indexes.zip"
with zipfile.ZipFile(index_zip,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as zf:
    for pair in pairs.values():
        tpi=pair.get(".tpi")
        tpd=pair.get(".tpd")
        if not tpi or not tpd:
            continue
        tpi_path=ROOT/tpi["staged_path"]
        tpd_path=ROOT/tpd["staged_path"]
        if not tpi_path.is_file() or not tpd_path.is_file():
            continue
        ti=tpi_path.read_bytes()
        td=tpd_path.read_bytes()
        report={"tpi_source":tpi["source_path"],"tpd_source":tpd["source_path"],"tpi_bytes":len(ti),"tpd_bytes":len(td),"entries_declared":0,"entries_extracted":0,"entries_deduplicated":0,"entries_failed":0,"bytes_extracted":0,"extensions":{},"errors":[]}
        if not ti.startswith(b"NetDragonDatPkg"):
            report["errors"].append("TPI magic header mismatch")
            results.append(report)
            continue
        try:
            file_count,info_size=struct.unpack_from("<II",ti,0x24)
            record_offset=0x2C
            record_end=record_offset+file_count*24
            if file_count>500000 or record_end>len(ti) or record_offset+info_size>len(ti)+8:
                raise ValueError("TPI directory bounds are invalid")
            report["entries_declared"]=file_count
            stem=Path(tpi["source_path"].split("!")[-1]).stem
            for idx in range(file_count):
                name_off,data_off,size,zsize,flags,timestamp=struct.unpack_from("<6I",ti,record_offset+idx*24)
                try:
                    name=read_c_string(ti,name_off)
                    normalized=name.replace("\\","/").lstrip("/")
                    if ".." in normalized.split("/"):
                        raise ValueError("unsafe resource path")
                    packed_size=zsize if zsize>0 else size
                    if size>MAX_ENTRY_BYTES or data_off+packed_size>len(td):
                        raise ValueError("resource payload bounds are invalid")
                    payload=td[data_off:data_off+packed_size]
                    if zsize>0:
                        try:
                            decoded=zlib.decompress(payload)
                        except zlib.error:
                            decoded=zlib.decompress(payload,-15)
                    else:
                        decoded=payload
                    if len(decoded)!=size:
                        raise ValueError(f"decoded size mismatch ({len(decoded)} != {size})")
                    digest=hashlib.sha256(decoded).hexdigest()
                    if digest in seen:
                        report["entries_deduplicated"]+=1
                        continue
                    category=classify(normalized)
                    dest=STAGE/category/"netdragon"/stem/safe_name(normalized)
                    dest.parent.mkdir(parents=True,exist_ok=True)
                    dest.write_bytes(decoded)
                    staged=dest.relative_to(ROOT).as_posix()
                    new_rows.append({"category":category,"source_archive":tpi["source_archive"],"source_path":tpi["source_path"]+"!"+normalized,"staged_path":staged,"size_bytes":len(decoded),"sha256":digest})
                    seen.add(digest)
                    report["entries_extracted"]+=1
                    report["bytes_extracted"]+=len(decoded)
                    ext=Path(normalized).suffix.lower() or "<none>"
                    report["extensions"][ext]=report["extensions"].get(ext,0)+1
                except Exception as error:
                    report["entries_failed"]+=1
                    if len(report["errors"])<30:
                        report["errors"].append(f"entry {idx}: {str(error)[:180]}")
            if report["entries_extracted"]>0:
                zf.write(tpi_path,arcname=f"{stem}.tpi")
                remove_paths.update([tpi["staged_path"],tpd["staged_path"]])
        except Exception as error:
            report["errors"].append(str(error)[:240])
        results.append(report)

for rel in remove_paths:
    path=ROOT/rel
    if path.exists():
        path.unlink()
rows=[row for row in rows if row["staged_path"] not in remove_paths]
rows.extend(new_rows)
rows.sort(key=lambda row:(row["category"],row["staged_path"]))
with INDEX_CSV.open("w",newline="",encoding="utf-8") as file:
    writer=csv.DictWriter(file,fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)

catalog={}
for row in rows:
    catalog.setdefault(row["category"],[]).append({"path":row["staged_path"],"source":row["source_path"],"extension":Path(row["source_path"].split("!")[-1]).suffix.lower(),"size_bytes":row["size_bytes"],"sha256":row["sha256"]})
CATALOG_JSON.parent.mkdir(parents=True,exist_ok=True)
CATALOG_JSON.write_text(json.dumps({"catalog_version":2,"asset_counts":{k:len(v) for k,v in catalog.items()},"assets":catalog},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

audit=json.loads(AUDIT_JSON.read_text(encoding="utf-8")) if AUDIT_JSON.exists() else {}
audit["unique_supported_files"]=len(rows)
audit["staged_bytes"]=sum(int(row["size_bytes"]) for row in rows)
audit["category_counts"]=dict(collections.Counter(row["category"] for row in rows))
audit["extension_counts"]=dict(collections.Counter(Path(row["source_path"].split("!")[-1]).suffix.lower() or "<none>" for row in rows))
audit["netdragon_tpi_tpd"]=results
AUDIT_JSON.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
(REPORTS/"tpi-extraction-audit.json").write_text(json.dumps({"pairs":results,"extracted_unique_files":len(new_rows),"extracted_bytes":sum(int(r["size_bytes"]) for r in new_rows),"category_counts":dict(collections.Counter(r["category"] for r in new_rows))},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
with (REPORTS/"source-format-samples.txt").open("a",encoding="utf-8") as file:
    for row in new_rows:
        ext=Path(row["source_path"].split("!")[-1]).suffix.lower()
        if ext in {".c3",".mjp",".pvr"}:
            sample=(ROOT/row["staged_path"]).read_bytes()[:96]
            file.write(f"\n### extracted {ext} | {row['source_path']} | {row['size_bytes']} bytes\n")
            file.write("HEX: "+sample.hex(" ")+"\n")
            file.write("ASCII: "+sample[:32].decode("ascii",errors="replace")+"\n")
            break
print(json.dumps({"tpi_tpd_pairs":len(results),"extracted_unique_files":len(new_rows),"extracted_bytes":sum(int(r["size_bytes"]) for r in new_rows),"categories":dict(collections.Counter(r["category"] for r in new_rows)),"failures":sum(int(r["entries_failed"]) for r in results)},ensure_ascii=False,indent=2))
if not new_rows:
    raise SystemExit("No TPI/TPD assets extracted; refusing to publish empty model-resource generation.")
