#!/usr/bin/env python3
"""Decode Conquer Mobile MJP images to PNG while preserving the separate alpha plane."""
from __future__ import annotations
import argparse, hashlib, json, struct, zlib
from pathlib import Path

HEADER = struct.Struct("<8I")  # eight little-endian u32 values at file offset 4

def inflate(data: bytes) -> bytes:
    errors=[]
    for window in (-15, 15, 31):
        try:
            return zlib.decompress(data, window)
        except zlib.error as exc:
            errors.append(str(exc))
    raise ValueError("DEFLATE stream rejected: " + " | ".join(errors))

def apply_alpha(alpha: bytes, rgba: bytearray, width: int, height: int) -> str:
    count=width*height
    if len(alpha) in (count, count+16):
        start=len(alpha)-count
        for i in range(count): rgba[i*4+3]=alpha[start+i]
        return "8-bit"
    half=(count+1)//2
    if len(alpha) in (half, half+16):
        start=len(alpha)-half
        for i in range(count):
            v=alpha[start+(i>>1)]
            nib=(v & 15) if (i & 1)==0 else ((v>>4)&15)
            rgba[i*4+3]=nib*17
        return "4-bit"
    raise ValueError(f"alpha plane length {len(alpha)} is incompatible with {count} pixels")

def decode_mjp(data: bytes):
    if len(data)<36 or data[:3]!=b"MJP":
        raise ValueError("not a valid MJP header")
    data_offset,b1_total,b1_comp,b1_raw,b2_offset,b2_comp,b2_raw,num_blocks=HEADER.unpack_from(data,4)
    if data_offset<36 or data_offset>len(data): raise ValueError("invalid MJP data offset")
    if b1_comp<=0 or b1_total<b1_comp or data_offset+b1_total>len(data):
        raise ValueError("invalid first MJP block bounds")
    if b1_raw>512*1024*1024 or b2_raw>512*1024*1024:
        raise ValueError("unreasonable MJP decompressed size")
    jpeg_head=inflate(data[data_offset:data_offset+b1_comp])
    if b1_raw and len(jpeg_head)!=b1_raw: raise ValueError(f"JPEG head size mismatch: expected {b1_raw}, got {len(jpeg_head)}")
    jpeg=jpeg_head+data[data_offset+b1_comp:data_offset+b1_total]
    alpha=None
    if b2_comp:
        if b2_offset<data_offset+b1_total or b2_offset+b2_comp>len(data):
            raise ValueError("invalid MJP alpha block bounds")
        alpha=inflate(data[b2_offset:b2_offset+b2_comp])
        if b2_raw and len(alpha)!=b2_raw: raise ValueError(f"alpha size mismatch: expected {b2_raw}, got {len(alpha)}")
    return jpeg,alpha,{"blocks":num_blocks,"jpeg_head_bytes":len(jpeg_head),"jpeg_bytes":len(jpeg),"alpha_bytes":len(alpha) if alpha is not None else 0}

def decode_file(src: Path, dst: Path) -> dict:
    raw=src.read_bytes()
    jpeg,alpha,meta=decode_mjp(raw)
    try:
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError("Pillow is required: pip install Pillow") from exc
    import io
    with Image.open(io.BytesIO(jpeg)) as image:
        image=image.convert("RGBA")
        width,height=image.size
        pixels=bytearray(image.tobytes())
    alpha_mode="none"
    if alpha is not None: alpha_mode=apply_alpha(alpha,pixels,width,height)
    dst.parent.mkdir(parents=True,exist_ok=True)
    Image.frombytes("RGBA",(width,height),bytes(pixels)).save(dst,"PNG")
    return {"source":str(src),"output":str(dst),"source_sha256":hashlib.sha256(raw).hexdigest(),
            "output_sha256":hashlib.sha256(dst.read_bytes()).hexdigest(),"width":width,"height":height,
            "alpha_mode":alpha_mode,**meta}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("source",type=Path)
    ap.add_argument("--out",type=Path,required=True)
    args=ap.parse_args()
    files=[args.source] if args.source.is_file() else sorted(args.source.rglob("*"))
    files=[p for p in files if p.is_file() and (p.suffix.lower()==".mjp" or (p.is_file() and p.read_bytes()[:3]==b"MJP"))]
    report={"source":str(args.source),"found":len(files),"decoded":[],"errors":[]}
    for src in files:
        rel=src.name if args.source.is_file() else str(src.relative_to(args.source))
        dst=args.out/(Path(rel).with_suffix(".png"))
        try: report["decoded"].append(decode_file(src,dst))
        except Exception as exc: report["errors"].append({"source":str(src),"error":str(exc)})
    report["decoded_count"]=len(report["decoded"])
    args.out.mkdir(parents=True,exist_ok=True)
    (args.out/"mjp-decode-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"found":report["found"],"decoded":report["decoded_count"],"errors":len(report["errors"]),"output":str(args.out)},ensure_ascii=False,indent=2))

if __name__=="__main__": main()
