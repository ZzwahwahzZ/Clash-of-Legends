#!/usr/bin/env python3
"""Extract and audit original Conquer WDB/TPI/TPD resources and C3 skeleton/motion chunks."""
from __future__ import annotations
import argparse, collections, hashlib, io, json, re, shutil, struct, tempfile, zipfile, zlib
from pathlib import Path

CIPHER_KEY = [0x193aa698,0x5496f7d5,0x4208931b,0x7a4106ec,0x83e86840,0xf49b6f8c,0xba3d9a51,0x55f54ddd,0x2de51372,0x9afb571b,0x3ab35406,0xad64ff1f,0xc77764fe,0x7f864466,0x416d9cd4,0xa2489278,0xe30b86e4,0x0b5231b6,0xba67aed6,0xe5ab2467,0x60028b90,0x1d9e20c6,0x2a7c692a,0x6b691cdb,0x9e51f817,0x9b763dec,0x3d29323f,0xcfe12b68,0x754b459b,0xa2238047,0xd9c55514,0x6bdcffc1,0x693e6340,0x82383fe7,0x1916ea5f,0xec7bcd59,0x72de165a,0xe79a1617,0x8ec86234,0xa8f0d284,0x20c90226,0x7bf98884,0x28a58331,0x3ec3fa6e,0x4ce0895b,0xc353b4d0,0x33ef064f,0x21e5e210,0xc8bb589d,0xe85dcab2,0xac65829f,0xa7bf92d0,0x05a6174d,0x25a50c2e,0xe5c78777,0x3d75021f,0x4baa9c98,0x23bdc884,0x9653bbd7,0xbadce7f5,0xc283a484,0xc040df2e,0x9370a841,0x2f316022,0x36eed231,0xac2cbc0c,0x13c0a49b,0xcdd12997,0x07fe91b2,0xcd7eabcd,0x2c01271d,0x18432df8,0x599c6bc7,0x75e93d5a,0xb67a6ee2,0x8e738e16,0xff9073fd,0xaf77026a,0xf86ea2fc,0x91509ea3,0x33a78dc6,0x4f79234a,0x3a7535bc,0x3539fcb1,0x3103ee52,0x4f6f1e69,0x6bb3ebbc,0x4cb77555,0x8dd1e999,0x2ade439d,0x11521fae,0xb94d2545,0x8dde9abd,0x1909393f,0xb792a23d,0x749c455b,0xb5b60f2c,0x380459ce,0x0dad5820,0xb130845b,0x291cbd52,0xde9a5bb7,0x51def961,0x515b6408,0xca6e823e,0x382e6e74,0xeebe3d71,0x4c8f0c6a,0xe676dcea,0x14e1dc7c,0x6f7fc634,0xcf85a943,0xd39ea96e,0x136e7c93,0x7164b304,0xf32f1333,0x35c34034,0xde39d721,0x91a87439,0xc410111f,0x29f17aac,0x1316a6ff,0x12f194ee,0x420b9499,0xf72db0dc,0x690b9f93,0x17d14bb2,0x8f931ab8,0x217500bc,0x875413f8,0x98b2e43d,0xc51f9571,0x54cebdca,0x0719cc79,0xf3c7080d,0xe4286771,0xa3eab3cd,0x4a6b00e0,0x11cf0759,0x7e897379,0x5b32876c,0x5e8cd4f6,0x0cedfa64,0x919ac2c7,0xb214f3b3,0x0e89c38c,0xf0c43a39,0xeae10522,0x835bce06,0x9eec43c2,0xea26a9d6,0x69531821,0x6725b24a,0xda81b0e2,0xd5b4ae33,0x080f99fb,0x15a83daf,0x29dfc720,0x91e1900f,0x28163d58,0x83d107a2,0x4eac149a,0x9f71da18,0x61d5c4fa,0xe3ab2a5f,0xc7b0d63f,0xb3cc752a,0x61ebcfb6,0x26ffb52a,0xed789e3f,0xaa3bc958,0x455a8788,0xc9c082a9,0x0a1bef0e,0xc29a5a7e,0x150d4735,0x943809e0,0x69215510,0xef0b0da9,0x3b4e9fb3,0xd8b5d04c,0xc7a023a8,0xb0d50288,0x64821375,0xc260e8cf,0x8496bd2c,0xff4f5435,0x0fb5560c,0x7cd74a52,0x93589c80,0x88975c47,0x83bda89d,0x8bcc4296,0x01b82c21,0xfd821dbf,0x26520b47,0x04983e19,0xd3e1ca27,0x782c580f,0x326ff573,0xc157bcc7,0x4f5e6b84,0x44ebfbfb,0xda26d9d8,0x6cd9d08e,0x1719f1d8,0x715c0487,0x2c2d3c92,0x53faaba9,0xbc836146,0x510c92d6,0xe089f82a,0x4680171f,0x369f00de,0x70ec2331,0x0e253d55,0xdafb9717,0xe5dd922d,0x95915d21,0xa0202f96,0xa161cc47,0xeacfa6f1,0xed5e9189,0xdab87684,0xa4b76d4a,0xfa704897,0x631f10ba,0xd39da8f9,0x5db4c0e4,0x16fde42a,0x2dff7580,0xb56fec7e,0xc3ffb370,0x8e6f36bc,0x6097d459,0x514d5d36,0xa5a737e2,0x3977b9b3,0xfd31a0ca,0x903368db,0xe8370d61,0x98109520,0xade23cac,0x99f82e04,0x41de7ea3,0x84a1c295,0x09191be0,0x30930d02,0x1c9fa44a,0xc406b6d7,0xeedca152,0x6149809c,0xb0099ef4,0xc5f653a5,0x4c10790d,0x7303286c]
WDB_ENTRY_SIZE = 84
TPI_MAGIC = b"NetDragonDatPkg"
C3_MAGIC = b"MAXFILE C3 00001"
TARGET_DBC = {
    "3dobj.dbc", "3dtexture.dbc", "3dmotion.dbc", "3dskeleton.dbc",
    "3dobjprop.dbc", "rolepart.dbc", "armor.dbc", "head.dbc",
    "weapon.dbc", "mount.dbc", "shield.dbc", "misc.dbc",
    "armet.dbc", "armet1.dbc", "mountmotion.dbc", "weaponmotion.dbc",
    "miscmotion.dbc", "3dsimplerole.dbc"
}
BASE_FAMILIES = {
    "001000000.c3": "small_female",
    "002000000.c3": "large_female",
    "003000000.c3": "small_male",
    "004000000.c3": "large_male"
}

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def u32(data: bytes, off: int) -> int:
    return struct.unpack_from("<I", data, off)[0]

def decrypt_wdb_block(block: bytes) -> bytes:
    if len(block) != WDB_ENTRY_SIZE or len(block) % 4:
        raise ValueError("invalid WDB encrypted block size")
    out = bytearray(block)
    a, b = 0xEFFEAABB, 0xEEEEEEEE
    for pos in range(0, len(out), 4):
        word = struct.unpack_from("<I", out, pos)[0]
        b = (b + CIPHER_KEY[a & 0xFF]) & 0xFFFFFFFF
        dec = ((b + a) & 0xFFFFFFFF) ^ word
        struct.pack_into("<I", out, pos, dec & 0xFFFFFFFF)
        a = ((a >> 11) | (((~a << 0x15) + 0x11111111) & 0xFFFFFFFF)) & 0xFFFFFFFF
        b = (b + dec + ((b << 5) & 0xFFFFFFFF) + 3) & 0xFFFFFFFF
    return bytes(out)

def parse_wdb(data: bytes) -> dict:
    if len(data) < 16 or data[:4] != b"BDMG":
        raise ValueError("c3.wdb does not have BDMG header")
    declared_size, table_off, count = struct.unpack_from("<iiI", data, 4)
    table_end = table_off + count * WDB_ENTRY_SIZE
    if table_off < 16 or table_end > len(data) or count > 500000:
        raise ValueError(f"invalid WDB table bounds offset={table_off} count={count} size={len(data)}")
    entries = []
    for i in range(count):
        raw = data[table_off+i*WDB_ENTRY_SIZE:table_off+(i+1)*WDB_ENTRY_SIZE]
        row = decrypt_wdb_block(raw)
        file_hash, offset, size = struct.unpack_from("<Iii", row, 0)
        name = row[20:84].split(b"\0",1)[0].decode("ascii", "replace")
        valid = bool(name) and offset >= 0 and size >= 0 and offset + size <= len(data)
        if not valid:
            continue
        payload = data[offset:offset+size]
        ext = Path(name.replace("\\","/")).suffix.lower()
        item = {"name":name,"hash":file_hash,"offset":offset,"size_bytes":size,
                "sha256":sha(payload),"magic_hex":payload[:16].hex(),
                "magic_ascii":payload[:16].decode("latin1","replace"),
                "extension":ext}
        if Path(name.replace("\\\\","/")).name.lower() in TARGET_DBC:
            item["dbc"] = inspect_dbc(name, payload)
        entries.append(item)
    ext_counts = collections.Counter(x["extension"] or "[none]" for x in entries)
    return {
        "magic":"BDMG","declared_size":declared_size,"actual_size":len(data),
        "entry_table_offset":table_off,"declared_entry_count":count,
        "valid_named_entries":len(entries),"extension_counts":dict(sorted(ext_counts.items())),
        "entries":entries
    }

def read_cstring(data: bytes, offset: int, limit=4096) -> str:
    if offset < 0 or offset >= len(data): return ""
    end = data.find(b"\0", offset, min(len(data), offset+limit))
    if end < 0: end = min(len(data), offset+limit)
    return data[offset:end].decode("latin1","replace")

def parse_rsdb(data: bytes, prefer_big=False) -> dict | None:
    if len(data) < 8 or data[:4] not in (b"RSDB",b"RSDC"):
        return None
    count = struct.unpack_from("<i", data, 4)[0]
    if count < 0 or count > 1000000: return {"magic":data[:4].decode("ascii","replace"),"count_invalid":count}
    candidates = [("big",12),("small",8)] if (prefer_big or data[:4]==b"RSDC") else [("small",8),("big",12)]
    best = None
    for kind, stride in candidates:
        table_end = 8 + count*stride
        if table_end > len(data): continue
        rows=[]; score=0
        for i in range(count):
            p=8+i*stride
            if kind=="big":
                rid, off=struct.unpack_from("<QI",data,p)
            else:
                rid, off=struct.unpack_from("<II",data,p)
            path=read_cstring(data,off)
            plausible=bool(path) and all((ch.isprintable() or ch in "\t\r\n") for ch in path)
            if plausible: score+=1
            if len(rows)<12: rows.append({"id":rid,"offset":off,"path":path})
        candidate={"magic":data[:4].decode("ascii"),"count":count,"key_width":64 if kind=="big" else 32,
                   "entry_stride":stride,"plausible_paths":score,"sample_rows":rows}
        if best is None or score>best["plausible_paths"]: best=candidate
    return best

def inspect_dbc(name: str, data: bytes) -> dict:
    result={"size_bytes":len(data),"magic_hex":data[:16].hex(),
            "magic_ascii":data[:16].decode("latin1","replace")}
    prefer_big=any(x in name.lower() for x in ("motion","3dtexture"))
    rsdb=parse_rsdb(data,prefer_big)
    if rsdb is not None: result["rsdb"]=rsdb
    return result

def parse_tpi(data: bytes) -> dict:
    if len(data)<0x30 or data[:len(TPI_MAGIC)]!=TPI_MAGIC:
        raise ValueError("invalid TPI magic/header")
    version=struct.unpack_from("<q",data,0x10)[0]
    count=struct.unpack_from("<I",data,0x24)[0]
    if version!=1000 or count>2000000: raise ValueError(f"unsupported TPI version/count {version}/{count}")
    pos=0x30; entries=[]; malformed=0
    for i in range(count):
        if pos>=len(data): malformed+=1; break
        path_len=data[pos]; pos+=1
        if pos+path_len+22>len(data): malformed+=1; break
        path=data[pos:pos+path_len].decode("latin1","replace"); pos+=path_len
        pos+=2
        unc, comp, comp2, unc2, offset=struct.unpack_from("<IIIII",data,pos); pos+=20
        if comp!=comp2 or unc!=unc2: malformed+=1; continue
        norm=path.lower().replace("\\","/").lstrip("/")
        entries.append({"path":norm,"offset":offset,"compressed_size":comp,"uncompressed_size":unc})
    return {"version":version,"declared_count":count,"parsed_count":len(entries),
            "malformed_count":malformed,"entries":entries}

def decompress_entry(tpd: bytes, entry: dict) -> bytes:
    off, size, expected=entry["offset"],entry["compressed_size"],entry["uncompressed_size"]
    if off<0 or size<0 or off+size>len(tpd): raise ValueError("TPD entry outside package bounds")
    comp=tpd[off:off+size]
    if size==expected: return comp
    errors=[]
    if len(comp)>=2 and comp[0]==0x78:
        try:
            out=zlib.decompress(comp)
            if len(out)==expected:return out
        except Exception as e: errors.append(str(e))
    for wbits in (-15,15):
        try:
            out=zlib.decompress(comp,wbits)
            if len(out)==expected:return out
        except Exception as e: errors.append(str(e))
    raise ValueError("decompression failed/size mismatch: "+("; ".join(errors[-2:])))

def ascii_runs(data: bytes, min_len=4, max_items=20):
    runs=re.findall(rb"[\x20-\x7e]{%d,}"%min_len,data)
    return [x[:160].decode("ascii","replace") for x in runs[:max_items]]

def inspect_phy(tag: str, payload: bytes) -> dict:
    out={"tag":tag,"payload_size":len(payload)}
    if len(payload)<16:return out
    name_len=u32(payload,0)
    if name_len>4096 or 4+name_len+12>len(payload):return out
    name=payload[4:4+name_len].split(b"\0",1)[0].decode("latin1","replace")
    p=4+name_len
    blend,normal,alpha=struct.unpack_from("<III",payload,p);p+=12
    morph=4 if tag=="PHY " else 1
    extra=12 if tag=="PHY3" else (20 if tag=="PHY5" else 0)
    stride=morph*12+8+4+8+8+extra
    total=normal+alpha
    if total>2000000 or p+total*stride>len(payload):
        out.update({"name":name,"blend_count":blend,"normal_vertices":normal,"alpha_vertices":alpha,
                    "vertex_stride":stride,"vertex_data_bounds":"INVALID"})
        return out
    hist=collections.Counter(); weighted=collections.Counter(); max_index=-1
    for i in range(total):
        q=p+i*stride+morph*12+8+4
        b1,b2=struct.unpack_from("<II",payload,q)
        w1,w2=struct.unpack_from("<ff",payload,q+8)
        for bi,w in ((b1,w1),(b2,w2)):
            if w>0 and bi<100000:
                hist[str(bi)]+=1;weighted[str(bi)]+=round(w,5);max_index=max(max_index,bi)
    out.update({"name":name,"blend_count":blend,"normal_vertices":normal,"alpha_vertices":alpha,
                "vertex_stride":stride,"used_bone_indices":dict(sorted(hist.items(),key=lambda x:int(x[0]))),
                "max_used_bone_index":max_index})
    return out

def inspect_motion(payload: bytes, include_translations=False) -> dict:
    out={"payload_size":len(payload)}
    if len(payload)<12:return out
    bones,frames=struct.unpack_from("<II",payload,0)
    tag=payload[8:12].decode("ascii","replace")
    out.update({"bone_count":bones,"frame_count":frames,"key_format":tag})
    if len(payload)>=16: out["keyframe_count"]=u32(payload,12)
    if not include_translations or bones>512 or len(payload)<16:return out
    count=u32(payload,12)
    p=16; positions=[]
    try:
        if tag=="KKEY":
            if count<1 or p+4+bones*64>len(payload):return out
            frame=struct.unpack_from("<I",payload,p)[0];p+=4
            for b in range(bones):
                vals=struct.unpack_from("<16f",payload,p+b*64)
                positions.append({"bone":b,"translation":[round(x,6) for x in vals[12:15]]})
            out["first_keyframe_position"]=frame
        elif tag=="ZKEY":
            if count<1 or p+2+bones*28>len(payload):return out
            frame=struct.unpack_from("<H",payload,p)[0];p+=2
            for b in range(bones):
                vals=struct.unpack_from("<7f",payload,p+b*28)
                positions.append({"bone":b,"translation":[round(x,6) for x in vals[4:7]]})
            out["first_keyframe_position"]=frame
        elif tag=="XKEY":
            if count<1 or p+2+bones*48>len(payload):return out
            frame=struct.unpack_from("<H",payload,p)[0];p+=2
            for b in range(bones):
                vals=struct.unpack_from("<12f",payload,p+b*48)
                positions.append({"bone":b,"translation":[round(x,6) for x in vals[9:12]]})
            out["first_keyframe_position"]=frame
        if positions:out["first_frame_bone_translations"]=positions
    except (struct.error,OverflowError):
        out["translation_decode"]="BOUNDS_OR_FORMAT_MISMATCH"
    return out

def inspect_c3(data: bytes, path: str) -> dict:
    if len(data)<16 or data[:16].rstrip(b"\0")!=C3_MAGIC:
        return {"path":path,"size_bytes":len(data),"valid_c3_header":False,"prefix_hex":data[:32].hex()}
    pos=16; chunks=[]; errors=[]; motion_index=0
    family=BASE_FAMILIES.get(Path(path).name.lower())
    while pos+8<=len(data):
        tag_bytes=data[pos:pos+4]; size=u32(data,pos+4); start=pos+8; end=start+size
        tag=tag_bytes.decode("ascii","replace")
        if end>len(data):
            errors.append({"offset":pos,"tag":tag,"declared_size":size,"remaining":len(data)-start})
            break
        payload=data[start:end]
        item={"tag":tag,"offset":pos,"payload_size":size}
        if tag=="MOTI":
            item.update(inspect_motion(payload,include_translations=(family is not None)))
            motion_index+=1
        elif tag.startswith("PHY"):
            item.update(inspect_phy(tag,payload))
        elif tag=="MNEW":
            item.update({"sha256":sha(payload),"prefix_hex":payload[:160].hex(),
                         "ascii_runs":ascii_runs(payload)})
        chunks.append(item)
        pos=end
    counts=collections.Counter(x["tag"] for x in chunks)
    return {"path":path,"family":family,"size_bytes":len(data),"valid_c3_header":True,
            "chunk_count":len(chunks),"chunk_counts":dict(sorted(counts.items())),
            "chunks":chunks,"parse_errors":errors,"trailing_bytes":len(data)-pos}

def inspect_package(archive_name: str, apk: zipfile.ZipFile, tpi_name: str) -> dict:
    names={n.lower():n for n in apk.namelist()}
    tpd_name=tpi_name[:-4]+".tpd"
    if tpd_name.lower() not in names:
        return {"tpi_path":tpi_name,"error":"matching TPD file missing"}
    tpi=apk.read(tpi_name); tpd=apk.read(names[tpd_name.lower()])
    index=parse_tpi(tpi)
    entries=index.pop("entries")
    ext=collections.Counter(Path(e["path"]).suffix.lower() or "[none]" for e in entries)
    c3_entries=[e for e in entries if e["path"].lower().endswith(".c3")]
    c3_reports=[]; c3_errors=[]
    for e in c3_entries:
        try:
            raw=decompress_entry(tpd,e)
            c3_reports.append(inspect_c3(raw,e["path"]))
        except Exception as exc:
            c3_errors.append({"path":e["path"],"error":f"{type(exc).__name__}: {exc}"})
    family_reports={}
    for family in BASE_FAMILIES.values():
        family_reports[family]=[x for x in c3_reports if x.get("family")==family]
    return {
        "tpi_path":tpi_name,"tpd_path":names[tpd_name.lower()],
        "tpi_size_bytes":len(tpi),"tpd_size_bytes":len(tpd),**index,
        "extension_counts":dict(sorted(ext.items())),
        "c3_entry_count":len(c3_entries),
        "c3_valid_header_count":sum(x.get("valid_c3_header",False) for x in c3_reports),
        "c3_family_counts":{k:len(v) for k,v in family_reports.items()},
        "c3_entries":c3_reports,"c3_errors":c3_errors
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",type=Path)
    ap.add_argument("--output",type=Path,required=True)
    args=ap.parse_args()
    report={"schema_version":"1.0.0","source_archive":args.archive.name,"apk_packages":[],"wdb_packages":[],"errors":[]}
    with zipfile.ZipFile(args.archive) as outer:
        for info in outer.infolist():
            if info.is_dir() or not info.filename.lower().endswith(".apk"):continue
            if not any(x in info.filename.lower() for x in ("conqueronline-1.1.2.3.apk","install_time_1001.apk")):continue
            try:
                with outer.open(info) as src, tempfile.NamedTemporaryFile(suffix=".apk") as tmp:
                    shutil.copyfileobj(src,tmp,length=1024*1024);tmp.flush()
                    with zipfile.ZipFile(tmp.name) as apk:
                        apk_names={n.lower():n for n in apk.namelist()}
                        for nlow,nreal in apk_names.items():
                            if nlow.endswith("/c3.wdb") or nlow=="assets/conquerres/ini/c3.wdb":
                                try:
                                    wdb=apk.read(nreal)
                                    parsed=parse_wdb(wdb)
                                    report["wdb_packages"].append({"apk":info.filename,"path":nreal,**parsed})
                                except Exception as exc:
                                    report["errors"].append({"apk":info.filename,"path":nreal,"error":f"{type(exc).__name__}: {exc}"})
                        tpi_files=[n for n in apk.namelist() if n.lower().endswith(".tpi") and "/conquerres/" in n.lower()]
                        package_summaries=[]
                        for tpi_name in tpi_files:
                            try: package_summaries.append(inspect_package(info.filename,apk,tpi_name))
                            except Exception as exc: report["errors"].append({"apk":info.filename,"tpi":tpi_name,"error":f"{type(exc).__name__}: {exc}"})
                        report["apk_packages"].append({"apk":info.filename,"tpi_package_count":len(package_summaries),"packages":package_summaries})
            except Exception as exc:
                report["errors"].append({"apk":info.filename,"error":f"{type(exc).__name__}: {exc}"})
    report["summary"]={
        "wdb_package_count":len(report["wdb_packages"]),
        "wdb_entry_count":sum(x.get("valid_named_entries",0) for x in report["wdb_packages"]),
        "tpi_package_count":sum(x.get("tpi_package_count",0) for x in report["apk_packages"]),
        "c3_entry_count":sum(p.get("c3_entry_count",0) for a in report["apk_packages"] for p in a.get("packages",[])),
        "valid_c3_count":sum(p.get("c3_valid_header_count",0) for a in report["apk_packages"] for p in a.get("packages",[])),
        "c3_parse_errors":sum(len(p.get("c3_errors",[])) for a in report["apk_packages"] for p in a.get("packages",[])),
        "mnew_chunk_count":sum(1 for a in report["apk_packages"] for p in a.get("packages",[]) for c in p.get("c3_entries",[]) for x in c.get("chunks",[]) if x.get("tag")=="MNEW"),
        "moti_chunk_count":sum(1 for a in report["apk_packages"] for p in a.get("packages",[]) for c in p.get("c3_entries",[]) for x in c.get("chunks",[]) if x.get("tag")=="MOTI"),
        "errors":len(report["errors"])
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report["summary"],ensure_ascii=False))
if __name__=="__main__":main()
