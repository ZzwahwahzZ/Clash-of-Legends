#!/usr/bin/env python3
"""Decode Conquer Mobile PVR v2/v3 textures to PNG.

PVRTC/ETC1/DXT blocks use the MIT-licensed texture2ddecoder package.
Uncompressed PVR v3 channel layouts and common PVR v2 mask layouts are decoded
locally. Unsupported pixel formats are reported rather than guessed.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
from PIL import Image

PVR3_MAGIC = 0x03525650
PVR2_MAGIC = 0x21525650
MAX_DIM = 8192
MAX_PIXELS = 64 * 1024 * 1024

def scale_channel(value: int, bits: int) -> int:
    if bits <= 0: return 255
    maximum = (1 << bits) - 1
    return (value * 255 + maximum // 2) // maximum

def decode_uncompressed_v3(data: bytes, width: int, height: int, lo: int, hi: int) -> bytes:
    chars = [chr((lo >> (8*i)) & 255).lower() for i in range(4)]
    bits = [(hi >> (8*i)) & 255 for i in range(4)]
    bpp = sum(bits)
    if bpp not in (8, 16, 24, 32, 64) or bpp % 8:
        raise ValueError(f"unsupported PVR3 uncompressed bit depth: {bpp}")
    bpp_bytes = bpp // 8
    count = width * height
    if len(data) < count * bpp_bytes:
        raise ValueError("truncated PVR3 pixel payload")
    output = bytearray(count * 4)
    shifts=[]; shift=0
    for n in bits:
        shifts.append(shift); shift += n
    for i in range(count):
        start=i*bpp_bytes
        pixel=int.from_bytes(data[start:start+bpp_bytes],"little")
        rgba=[0,0,0,255]
        luminance=None
        for ch,n,sh in zip(chars,bits,shifts):
            if n == 0: continue
            raw=(pixel >> sh) & ((1 << n)-1)
            val=scale_channel(raw,n)
            if ch == "r": rgba[0]=val
            elif ch == "g": rgba[1]=val
            elif ch == "b": rgba[2]=val
            elif ch == "a": rgba[3]=val
            elif ch in ("l","i"): luminance=val
        if luminance is not None: rgba[0]=rgba[1]=rgba[2]=luminance
        output[i*4:i*4+4]=bytes(rgba)
    return bytes(output)

def decode_v2(data: bytes) -> tuple[int,int,bytes,str]:
    if len(data) < 52: raise ValueError("truncated PVR v2 header")
    header_size,height,width,_,flags,bpp,r_mask,g_mask,b_mask,a_mask,magic=struct.unpack_from("<11I",data,0)
    if magic != PVR2_MAGIC: raise ValueError("invalid PVR v2 magic")
    if not (0 < width <= MAX_DIM and 0 < height <= MAX_DIM) or width*height > MAX_PIXELS:
        raise ValueError("invalid PVR v2 dimensions")
    if header_size < 52 or header_size > len(data): raise ValueError("invalid PVR v2 header size")
    src=data[header_size:]
    output=bytearray(width*height*4)
    fmt=flags & 0xff
    if bpp not in (8,16,24,32): raise ValueError(f"unsupported PVR v2 bpp {bpp}")
    bytes_per_pixel=bpp//8
    if len(src) < width*height*bytes_per_pixel: raise ValueError("truncated PVR v2 pixels")
    masks=(r_mask,g_mask,b_mask,a_mask)
    shifts=[]; widths=[]
    for mask in masks:
        if not mask: shifts.append(0); widths.append(0); continue
        shift=(mask & -mask).bit_length()-1
        shifts.append(shift); widths.append((mask >> shift).bit_length())
    for i in range(width*height):
        pixel=int.from_bytes(src[i*bytes_per_pixel:(i+1)*bytes_per_pixel],"little")
        rgba=[]
        for shift,bits in zip(shifts,widths):
            rgba.append(scale_channel((pixel>>shift)&((1<<bits)-1),bits) if bits else 255)
        output[i*4:i*4+4]=bytes(rgba)
    if fmt == 0x07:
        for i in range(width*height):
            v=src[i]; output[i*4:i*4+3]=bytes((v,v,v)); output[i*4+3]=255
    elif fmt == 0x08:
        for i in range(width*height):
            v,a=src[i*2:i*2+2]; output[i*4:i*4+4]=bytes((v,v,v,a))
    return width,height,bytes(output),f"PVR2_{bpp}bpp_fmt_{fmt:02x}"

def decode_pvr(data: bytes) -> tuple[int,int,bytes,str]:
    if len(data)<52: raise ValueError("file too short for PVR header")
    magic=struct.unpack_from("<I",data,0)[0]
    if magic == PVR2_MAGIC:
        return decode_v2(data)
    if magic != PVR3_MAGIC: raise ValueError("unknown PVR magic")
    lo,hi=struct.unpack_from("<II",data,8)
    height,width=struct.unpack_from("<II",data,24)
    meta_size=struct.unpack_from("<I",data,48)[0]
    offset=52+meta_size
    if not (0 < width <= MAX_DIM and 0 < height <= MAX_DIM) or width*height > MAX_PIXELS:
        raise ValueError("invalid PVR3 dimensions")
    if offset>len(data): raise ValueError("PVR3 metadata exceeds file")
    payload=data[offset:]
    if hi:
        rgba=decode_uncompressed_v3(payload,width,height,lo,hi)
        fmt="PVR3_uncompressed"
    else:
        code=lo & 0xffffffff
        try:
            import texture2ddecoder as td
        except ImportError as exc:
            raise RuntimeError("install texture2ddecoder to decode compressed PVR formats") from exc
        if code in (0,1,2,3):
            is2bpp=code in (0,1)
            decoded=td.decode_pvrtc(payload,width,height,is2bpp)
            fmt="PVRTC1_2bpp" if is2bpp else "PVRTC1_4bpp"
        elif code == 6:
            decoded=td.decode_etc1(payload,width,height); fmt="ETC1"
        elif code == 7:
            decoded=td.decode_bc1(payload,width,height); fmt="DXT1"
        elif code == 11:
            decoded=td.decode_bc3(payload,width,height); fmt="DXT5"
        else:
            raise ValueError(f"unsupported PVR3 compressed pixel format code {code}")
        if len(decoded) != width*height*4:
            raise ValueError(f"decoder returned {len(decoded)} bytes; expected {width*height*4}")
        # texture2ddecoder returns BGRA bytes.
        rgba=bytes(channel for i in range(0,len(decoded),4) for channel in (decoded[i+2],decoded[i+1],decoded[i],decoded[i+3]))
    return width,height,rgba,fmt

def decode_file(src: Path, dst: Path) -> dict:
    raw=src.read_bytes()
    width,height,rgba,fmt=decode_pvr(raw)
    dst.parent.mkdir(parents=True,exist_ok=True)
    Image.frombytes("RGBA",(width,height),rgba).save(dst,"PNG")
    return {"source":str(src),"output":str(dst),"source_sha256":hashlib.sha256(raw).hexdigest(),
            "output_sha256":hashlib.sha256(dst.read_bytes()).hexdigest(),"width":width,"height":height,"format":fmt}

def run(source: Path, out: Path) -> dict:
    files=[source] if source.is_file() else sorted(p for p in source.rglob("*") if p.is_file())
    candidates=[]
    for p in files:
        try:
            with p.open("rb") as f:
                head=f.read(4)
            if len(head)==4 and (struct.unpack("<I",head)[0] in (PVR2_MAGIC,PVR3_MAGIC)):
                candidates.append(p)
        except OSError: pass
    report={"source":str(source),"found":len(candidates),"decoded":[],"errors":[]}
    for src in candidates:
        rel=src.name if source.is_file() else str(src.relative_to(source))
        try: report["decoded"].append(decode_file(src,out/Path(rel).with_suffix(".png")))
        except Exception as exc: report["errors"].append({"source":str(src),"error":str(exc)})
    report["decoded_count"]=len(report["decoded"])
    out.mkdir(parents=True,exist_ok=True)
    (out/"pvr-decode-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"found":report["found"],"decoded":report["decoded_count"],"errors":len(report["errors"]),"output":str(out)},ensure_ascii=False,indent=2))
    return report

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("source",type=Path)
    ap.add_argument("--out",type=Path,required=True)
    a=ap.parse_args()
    run(a.source,a.out)

if __name__=="__main__":
    main()
