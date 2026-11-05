#!/usr/bin/env python3
"""Decode NetDragon MJP JPEG+alpha textures into Godot-ready PNG files."""
from __future__ import annotations
import csv, hashlib, json, struct, zlib
from pathlib import Path
from io import BytesIO
from PIL import Image

ROOT=Path.cwd()
STAGE=ROOT/"resource_stage"
REPORTS=ROOT/"reports"
INDEX=REPORTS/"resource-source-index.csv"
CATALOG=STAGE/"world/resource_catalog.json"
MAPPING=STAGE/"world/resource_mappings/mjp_texture_map.json"
REPORT=REPORTS/"mjp-decode-report.json"


def inflate_checked(data: bytes, expected: int) -> bytes:
    if expected==0 and not data:
        return b""
    errors=[]
    for wbits in (zlib.MAX_WBITS,-zlib.MAX_WBITS):
        try:
            out=zlib.decompress(data,wbits)
            if len(out)==expected:
                return out
            errors.append(f"{len(out)} != {expected}")
        except zlib.error as exc:
            errors.append(str(exc))
    if len(data)==expected:
        return data
    raise ValueError("compressed block decode failed: "+"; ".join(errors)[:220])


def decode_alpha(data: bytes,width: int,height: int):
    count=width*height
    half=(count+1)//2
    d8=len(data)-count
    d4=len(data)-half
    if 0<=d8<=16 and (d4<0 or d8<=d4):
        return data[d8:d8+count],"A8",d8
    if 0<=d4<=16:
        packed=data[d4:d4+half]
        out=bytearray(count)
        for i in range(count):
            byte=packed[i>>1]
            nibble=(byte&0x0f) if (i&1)==0 else ((byte>>4)&0x0f)
            out[i]=nibble*17
        return bytes(out),"A4",d4
    raise ValueError(f"unsupported alpha plane: {len(data)} bytes for {width}x{height}")


def decode_mjp(blob: bytes):
    if len(blob)<36 or blob[:3]!=b"MJP":
        raise ValueError("MJP magic/header mismatch")
    data_offset,block1_total,block1_comp,block1_decomp,block2_offset,block2_comp,block2_decomp,num_blocks=struct.unpack_from("<8I",blob,4)
    if data_offset<36 or block1_comp>block1_total or data_offset+block1_total>len(blob):
        raise ValueError("MJP first-block bounds are invalid")
    head=inflate_checked(blob[data_offset:data_offset+block1_comp],block1_decomp)
    tail=blob[data_offset+block1_comp:data_offset+block1_total]
    jpeg=head+tail
    try:
        with Image.open(BytesIO(jpeg)) as source:
            source.load()
            rgba=source.convert("RGBA")
    except Exception as exc:
        raise ValueError(f"reconstructed JPEG invalid: {exc}") from exc
    alpha_mode="OPAQUE"
    alpha_prefix=0
    if block2_comp:
        if block2_offset<data_offset+block1_total or block2_offset+block2_comp>len(blob):
            raise ValueError("MJP alpha-block bounds are invalid")
        alpha_data=inflate_checked(blob[block2_offset:block2_offset+block2_comp],block2_decomp)
        alpha,alpha_mode,alpha_prefix=decode_alpha(alpha_data,rgba.width,rgba.height)
        rgba.putalpha(Image.frombytes("L",rgba.size,alpha))
    return rgba,{"width":rgba.width,"height":rgba.height,"num_blocks":num_blocks,
                 "alpha_mode":alpha_mode,"alpha_prefix_bytes":alpha_prefix,"jpeg_bytes":len(jpeg)}


def main():
    if not INDEX.is_file() or not CATALOG.is_file():
        raise SystemExit("resource index/catalog missing; MJP conversion must run after resource staging")
    rows=list(csv.DictReader(INDEX.open(encoding="utf-8-sig",newline="")))
    mjp_rows=[row for row in rows if row.get("staged_path","").lower().endswith(".mjp")]
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    assets=catalog.setdefault("assets",{})
    mapping={}
    failures=[]
    decoded_count=0
    total_png_bytes=0
    alpha_counts={}
    dimensions={}
    for row in mjp_rows:
        source=ROOT/row["staged_path"]
        if not source.is_file():
            failures.append({"source":row["staged_path"],"error":"staged MJP source missing"})
            continue
        try:
            blob=source.read_bytes()
            rgba,meta=decode_mjp(blob)
            output=source.with_suffix(source.suffix+".png")
            output.parent.mkdir(parents=True,exist_ok=True)
            rgba.save(output,format="PNG",optimize=False,compress_level=6)
            png_bytes=output.stat().st_size
            digest=hashlib.sha256(output.read_bytes()).hexdigest()
            category=row["category"]
            entry={"path":output.relative_to(ROOT).as_posix(),
                   "source":"Decoded from MJP: "+row["source_path"],
                   "extension":".png","size_bytes":png_bytes,"sha256":digest,
                   "derived_from":row["source_path"]}
            bucket=assets.setdefault(category,[])
            if not any(isinstance(item,dict) and item.get("path")==entry["path"] for item in bucket):
                bucket.append(entry)
            virtual=row["source_path"].split("!")[-1].replace("\\","/")
            mapping[virtual]={"source_path":row["staged_path"],"decoded_path":entry["path"],**meta,
                              "source_sha256":row["sha256"],"decoded_sha256":digest}
            decoded_count+=1
            total_png_bytes+=png_bytes
            alpha_counts[meta["alpha_mode"]]=alpha_counts.get(meta["alpha_mode"],0)+1
            size_key=f"{meta['width']}x{meta['height']}"
            dimensions[size_key]=dimensions.get(size_key,0)+1
        except Exception as exc:
            failures.append({"source":row["staged_path"],"error":str(exc)[:300]})
    MAPPING.parent.mkdir(parents=True,exist_ok=True)
    MAPPING.write_text(json.dumps({"format":"NetDragon MJP virtual-path to decoded PNG mapping",
        "version":1,"entry_count":len(mapping),"entries":mapping},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    map_entry={"path":MAPPING.relative_to(ROOT).as_posix(),"source":"Generated MJP virtual-path texture mapping",
               "extension":".json","size_bytes":MAPPING.stat().st_size,
               "sha256":hashlib.sha256(MAPPING.read_bytes()).hexdigest()}
    world_assets=assets.setdefault("world",[])
    if not any(isinstance(item,dict) and item.get("path")==map_entry["path"] for item in world_assets):
        world_assets.append(map_entry)
    catalog["asset_counts"]={key:len(value) for key,value in assets.items() if isinstance(value,list)}
    catalog["catalog_version"]=int(catalog.get("catalog_version",1))+1
    catalog["mjp_conversion"]={"source_files":len(mjp_rows),"decoded_pngs":decoded_count,
        "failed":len(failures),"decoded_png_bytes":total_png_bytes,"alpha_modes":alpha_counts,
        "dimensions":dimensions,"mapping":map_entry["path"]}
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    report={"format":"NetDragon MJP JPEG+alpha","source_files":len(mjp_rows),
        "decoded_pngs":decoded_count,"failed":len(failures),"decoded_png_bytes":total_png_bytes,
        "alpha_modes":alpha_counts,"dimensions":dimensions,"mapping_path":map_entry["path"],
        "failures":failures[:250]}
    REPORTS.mkdir(parents=True,exist_ok=True)
    REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({key:report[key] for key in ["source_files","decoded_pngs","failed",
        "decoded_png_bytes","alpha_modes"]},ensure_ascii=False,indent=2))
    if mjp_rows and decoded_count==0:
        raise SystemExit("No MJP texture could be decoded; refusing to accept raw MJP-only resources.")


if __name__=="__main__":
    main()
