#!/usr/bin/env python3
import struct
from pathlib import Path

bundle=Path("build/c3-sources.bin")
out=Path("build/c3-source")
if not bundle.is_file():
    raise SystemExit("C3 binary bundle is missing.")
data=bundle.read_bytes()
pos=0
if len(data)<4:
    raise SystemExit("C3 binary bundle header is truncated.")
count,=struct.unpack_from("<I",data,pos);pos+=4
written=0
total=0
for index in range(count):
    if pos+4>len(data): raise SystemExit(f"Truncated path length at record {index}.")
    path_len,=struct.unpack_from("<I",data,pos);pos+=4
    if path_len<1 or path_len>4096 or pos+path_len+8>len(data):
        raise SystemExit(f"Invalid path record {index}.")
    rel=data[pos:pos+path_len].decode("utf-8");pos+=path_len
    size,=struct.unpack_from("<Q",data,pos);pos+=8
    if size>128*1024*1024 or pos+size>len(data):
        raise SystemExit(f"Invalid payload size at record {index}.")
    payload=data[pos:pos+size];pos+=size
    if ".." in Path(rel).parts:
        raise SystemExit(f"Unsafe path in C3 bundle: {rel}")
    source=Path(rel)
    try:
        relative=source.relative_to("resource_stage/models")
    except ValueError:
        raise SystemExit(f"Unexpected staged C3 path: {rel}")
    dest=out/relative
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(payload)
    written+=1;total+=size
if pos!=len(data):
    raise SystemExit(f"Unexpected trailing bytes: {len(data)-pos}")
print(f"Extracted {written} C3 model files ({total} bytes) to {out}.")
