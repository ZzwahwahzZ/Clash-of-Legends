#!/usr/bin/env python3
"""Extract NetDragon TPI/TPD resources with explicit handling for known record variants."""
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

def inflate_checked(payload, expected):
    errors=[]
    for wbits in (zlib.MAX_WBITS, -zlib.MAX_WBITS):
        try:
            decoded=zlib.decompress(payload,wbits)
            if len(decoded)==expected:
                return decoded
            errors.append(f"decoded size {len(decoded)} != expected {expected}")
        except zlib.error as exc:
            errors.append(str(exc))
    raise ValueError("zlib decode failed: "+"; ".join(errors)[:240])

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
multiblock_zip=REPORTS/"tpi-multiblock-blocks.zip"
with zipfile.ZipFile(index_zip,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as index_out, \
     zipfile.ZipFile(multiblock_zip,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as blocks_out:
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
        report={"tpi_source":tpi["source_path"],"tpd_source":tpd["source_path"],
                "tpi_bytes":len(ti),"tpd_bytes":len(td),"entries_declared":0,
                "entries_extracted":0,"entries_deduplicated":0,"entries_failed":0,
                "entries_empty":0,"entries_multiblock_pending":0,"entries_multiblock_reconstructed":0,"bytes_extracted":0,
                "flag_counts":{},"extensions":{},"empty_entries":[],"multiblock_entries":[],"errors":[]}
        if len(ti)<0x30 or not ti.startswith(b"NetDragonDatPkg"):
            report["errors"].append("TPI magic header or header size mismatch")
            results.append(report)
            continue
        try:
            file_count=struct.unpack_from("<I",ti,0x24)[0]
            pos=0x30
            if file_count>500000:
                raise ValueError("TPI entry count is unreasonable")
            report["entries_declared"]=file_count
            stem=Path(tpi["source_path"].split("!")[-1]).stem
            for idx in range(file_count):
                entry_start=pos
                try:
                    if pos>=len(ti):
                        raise ValueError("TPI directory ended before declared entry count")
                    path_len=ti[pos]
                    pos+=1
                    if pos+path_len+2>len(ti):
                        raise ValueError("TPI entry name exceeds index bounds")
                    name=ti[pos:pos+path_len].decode("cp1252",errors="replace").strip()
                    pos+=path_len
                    flags=struct.unpack_from("<H",ti,pos)[0]
                    pos+=2
                    flag_key=str(flags)
                    report["flag_counts"][flag_key]=report["flag_counts"].get(flag_key,0)+1
                    normalized=name.replace("\\","/").lstrip("/")
                    if not normalized or ".." in normalized.split("/"):
                        raise ValueError("unsafe or empty resource path")

                    if flags==0:
                        if pos+8>len(ti):
                            raise ValueError("empty-record header exceeds TPI bounds")
                        empty_size,empty_comp=struct.unpack_from("<2I",ti,pos)
                        pos+=8
                        report["entries_empty"]+=1
                        if len(report["empty_entries"])<100:
                            report["empty_entries"].append({"index":idx,"path":normalized,"size":empty_size,"compressed_size":empty_comp})
                        if empty_size!=0 or empty_comp!=0:
                            raise ValueError("flag-0 record is not a zero-length placeholder")
                        continue

                    if flags==1:
                        if pos+20>len(ti):
                            raise ValueError("standard record header exceeds TPI bounds")
                        size,zsize,zsize_check,size_check,data_off=struct.unpack_from("<5I",ti,pos)
                        pos+=20
                        if zsize!=zsize_check or size!=size_check:
                            raise ValueError("flag-1 duplicate size fields disagree")
                        if size>MAX_ENTRY_BYTES or data_off+zsize>len(td):
                            raise ValueError("resource payload bounds are invalid")
                        payload=td[data_off:data_off+zsize]
                        decoded=payload if zsize==size else inflate_checked(payload,size)

                    elif flags==2:
                        # Verified two-block layout: total sizes, block-1 sizes/offset,
                        # then block-2 sizes/offset. The decoded blocks are retained for
                        # audit; PVR2 is staged only when its own header proves concatenation.
                        if pos+32>len(ti):
                            raise ValueError("two-block record header exceeds TPI bounds")
                        total_size,total_comp,block1_comp,block1_size,block1_off=struct.unpack_from("<5I",ti,pos)
                        block2_comp,block2_size,block2_off=struct.unpack_from("<3I",ti,pos+20)
                        pos+=32
                        if total_size!=block1_size+block2_size:
                            raise ValueError("two-block uncompressed size totals disagree")
                        if total_comp!=block1_comp+block2_comp:
                            raise ValueError("two-block compressed size totals disagree")
                        if block2_off!=block1_off+block1_comp:
                            raise ValueError("two-block payload offsets are not contiguous")
                        if total_size>MAX_ENTRY_BYTES or block1_off+block1_comp>len(td) or block2_off+block2_comp>len(td):
                            raise ValueError("two-block payload bounds are invalid")
                        raw1=td[block1_off:block1_off+block1_comp]
                        raw2=td[block2_off:block2_off+block2_comp]
                        decoded1=inflate_checked(raw1,block1_size) if block1_comp!=block1_size else raw1
                        decoded2=inflate_checked(raw2,block2_size) if block2_comp!=block2_size else raw2
                        base=f"{stem}/{safe_name(normalized)}"
                        blocks_out.writestr(base+".block1.bin",decoded1)
                        blocks_out.writestr(base+".block2.bin",decoded2)
                        combined=decoded1+decoded2
                        pvr_header=None
                        if Path(normalized).suffix.lower()==".pvr" and len(combined)>=52 and combined[44:48]==b"PVR!":
                            pvr_header=struct.unpack_from("<13I",combined,0)
                        if pvr_header:
                            header_size,height,width,mipmaps,flags_pvr,data_size,bpp,rmask,gmask,bmask,amask,magic,surfaces=pvr_header
                            pvr_valid=(header_size>=52 and header_size<=len(combined) and width>0 and height>0
                                       and bpp in (16,24,32) and magic==0x21525650
                                       and surfaces>=1 and header_size+data_size==len(combined)
                                       and len(combined)==total_size)
                        else:
                            pvr_valid=False
                        if pvr_valid:
                            digest=hashlib.sha256(combined).hexdigest()
                            category=classify(normalized)
                            dest=STAGE/category/"netdragon"/stem/safe_name(normalized)
                            dest.parent.mkdir(parents=True,exist_ok=True)
                            dest.write_bytes(combined)
                            staged=dest.relative_to(ROOT).as_posix()
                            new_rows.append({"category":category,"source_archive":tpi["source_archive"],
                                             "source_path":tpi["source_path"]+"!"+normalized,
                                             "staged_path":staged,"size_bytes":len(combined),"sha256":digest})
                            seen.add(digest)
                            report["entries_extracted"]+=1
                            report["entries_multiblock_reconstructed"]+=1
                            report["bytes_extracted"]+=len(combined)
                            ext=Path(normalized).suffix.lower()
                            report["extensions"][ext]=report["extensions"].get(ext,0)+1
                            report["multiblock_entries"].append({"index":idx,"path":normalized,"flags":flags,
                                "total_size":total_size,"reconstruction_status":"PVR2_CONCAT_VALIDATED",
                                "pvr2_header":{"width":width,"height":height,"mipmaps":mipmaps,"bpp":bpp,
                                               "header_size":header_size,"data_size":data_size,"surfaces":surfaces},
                                "block1_sha256":hashlib.sha256(decoded1).hexdigest(),
                                "block2_sha256":hashlib.sha256(decoded2).hexdigest()})
                        else:
                            pending={"index":idx,"path":normalized,"flags":flags,
                                     "total_size":total_size,"total_compressed_size":total_comp,
                                     "block1":{"compressed_size":block1_comp,"size":block1_size,"offset":block1_off,
                                               "sha256":hashlib.sha256(decoded1).hexdigest(),"header_hex":decoded1[:64].hex(" ")},
                                     "block2":{"compressed_size":block2_comp,"size":block2_size,"offset":block2_off,
                                               "sha256":hashlib.sha256(decoded2).hexdigest(),"header_hex":decoded2[:64].hex(" ")},
                                     "reconstruction_status":"PENDING_UNRECOGNIZED_TWO_BLOCK_FORMAT"}
                            report["entries_multiblock_pending"]+=1
                            report["multiblock_entries"].append(pending)
                        continue
                    else:
                        raise ValueError(f"unsupported TPI entry flags: {flags}")

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
                    new_rows.append({"category":category,"source_archive":tpi["source_archive"],
                                     "source_path":tpi["source_path"]+"!"+normalized,
                                     "staged_path":staged,"size_bytes":len(decoded),"sha256":digest})
                    seen.add(digest)
                    report["entries_extracted"]+=1
                    report["bytes_extracted"]+=len(decoded)
                    ext=Path(normalized).suffix.lower() or "<none>"
                    report["extensions"][ext]=report["extensions"].get(ext,0)+1
                except Exception as error:
                    report["entries_failed"]+=1
                    if len(report["errors"])<50:
                        report["errors"].append(f"entry {idx} at 0x{entry_start:x}: {str(error)[:180]}")
            if report["entries_extracted"]>0 or report["entries_multiblock_pending"]>0:
                index_out.writestr(f"{stem}.tpi",ti)
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
    catalog.setdefault(row["category"],[]).append({"path":row["staged_path"],"source":row["source_path"],
        "extension":Path(row["source_path"].split("!")[-1]).suffix.lower(),
        "size_bytes":row["size_bytes"],"sha256":row["sha256"]})
CATALOG_JSON.parent.mkdir(parents=True,exist_ok=True)
CATALOG_JSON.write_text(json.dumps({"catalog_version":3,"asset_counts":{k:len(v) for k,v in catalog.items()},
    "assets":catalog},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

audit=json.loads(AUDIT_JSON.read_text(encoding="utf-8")) if AUDIT_JSON.exists() else {}
audit["unique_supported_files"]=len(rows)
audit["staged_bytes"]=sum(int(row["size_bytes"]) for row in rows)
audit["category_counts"]=dict(collections.Counter(row["category"] for row in rows))
audit["extension_counts"]=dict(collections.Counter(Path(row["source_path"].split("!")[-1]).suffix.lower() or "<none>" for row in rows))
audit["netdragon_tpi_tpd"]=results
AUDIT_JSON.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
(REPORTS/"tpi-extraction-audit.json").write_text(json.dumps({
    "pairs":results,"extracted_unique_files":len(new_rows),
    "extracted_bytes":sum(int(r["size_bytes"]) for r in new_rows),
    "category_counts":dict(collections.Counter(r["category"] for r in new_rows)),
    "flag_counts":dict(collections.Counter(flag for pair in results for flag,count in pair.get("flag_counts",{}).items() for _ in range(count))),
    "multiblock_pending":sum(r["entries_multiblock_pending"] for r in results),
    "multiblock_reconstructed":sum(r.get("entries_multiblock_reconstructed",0) for r in results),
    "empty_placeholders":sum(r["entries_empty"] for r in results),
    "failed_entries":sum(r["entries_failed"] for r in results)
},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
with (REPORTS/"source-format-samples.txt").open("a",encoding="utf-8") as file:
    for row in new_rows:
        ext=Path(row["source_path"].split("!")[-1]).suffix.lower()
        if ext in {".c3",".mjp",".pvr"}:
            sample=(ROOT/row["staged_path"]).read_bytes()[:96]
            file.write(f"\n### extracted {ext} | {row['source_path']} | {row['size_bytes']} bytes\n")
            file.write("HEX: "+sample.hex(" ")+"\n")
            file.write("ASCII: "+sample[:32].decode("ascii",errors="replace")+"\n")
            break
total_failed=sum(int(r["entries_failed"]) for r in results)
total_multi=sum(int(r["entries_multiblock_pending"]) for r in results)
print(json.dumps({"tpi_tpd_pairs":len(results),"extracted_unique_files":len(new_rows),
    "extracted_bytes":sum(int(r["size_bytes"]) for r in new_rows),
    "categories":dict(collections.Counter(r["category"] for r in new_rows)),
    "multiblock_pending":total_multi,"failures":total_failed},ensure_ascii=False,indent=2))
if not new_rows and not total_multi:
    raise SystemExit("No TPI/TPD assets extracted; refusing to publish empty resource generation.")
