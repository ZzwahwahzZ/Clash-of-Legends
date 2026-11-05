#!/usr/bin/env python3
import struct
from pathlib import Path

def unpack_bundle(bundle, out, prefix):
    data=Path(bundle).read_bytes()
    pos=0
    if len(data)<4: raise SystemExit(f"{bundle}: truncated header")
    count,=struct.unpack_from("<I",data,pos);pos+=4
    written=0;total=0;missing=[]
    for index in range(count):
        if pos+4>len(data): raise SystemExit(f"{bundle}: truncated path length at {index}")
        path_len,=struct.unpack_from("<I",data,pos);pos+=4
        if path_len<1 or path_len>4096 or pos+path_len+8>len(data):
            raise SystemExit(f"{bundle}: invalid path record {index}")
        rel=data[pos:pos+path_len].decode("utf-8");pos+=path_len
        size,=struct.unpack_from("<Q",data,pos);pos+=8
        if size>128*1024*1024 or pos+size>len(data):
            raise SystemExit(f"{bundle}: invalid payload size at {index}")
        payload=data[pos:pos+size];pos+=size
        path=Path(rel)
        if ".." in path.parts: raise SystemExit(f"Unsafe path: {rel}")
        try: relative=path.relative_to(prefix)
        except ValueError: raise SystemExit(f"Unexpected path prefix: {rel}")
        if size==0:
            missing.append(rel);continue
        dest=Path(out)/relative
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(payload)
        written+=1;total+=size
    if pos!=len(data): raise SystemExit(f"{bundle}: trailing bytes {len(data)-pos}")
    print(f"{bundle}: extracted {written}/{count} files, {total} bytes; missing {len(missing)}")
    if missing: print("First missing:",missing[:10])
    if written==0: raise SystemExit(f"{bundle}: no files extracted")
    return written

unpack_bundle("build/c3-sources.bin","build/c3-source","resource_stage/models")
unpack_bundle("build/pvr-sources.bin","build/pvr-source","resource_stage/models")
