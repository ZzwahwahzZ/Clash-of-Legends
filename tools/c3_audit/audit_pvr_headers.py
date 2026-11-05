#!/usr/bin/env python3
import collections,json,struct
from pathlib import Path

rows=[]
for path in sorted(Path("build/pvr-source").rglob("*.pvr")):
    data=path.read_bytes()
    row={"path":path.relative_to("build/pvr-source").as_posix(),"size_bytes":len(data),"magic":data[:4].hex()}
    if len(data)>=52 and data[:4]==b"PVR\x03":
        pixel_format=struct.unpack_from("<Q",data,8)[0]
        color_space,channel_type,height,width,depth,surfaces,faces,mips,metadata=struct.unpack_from("<9I",data,16)
        row.update({"version":3,"pixel_format":pixel_format,"format_id":pixel_format&0xffffffff,"color_space":color_space,"channel_type":channel_type,"width":width,"height":height,"depth":depth,"surfaces":surfaces,"faces":faces,"mipmaps":mips,"metadata_bytes":metadata,"data_offset":52+metadata,"payload_bytes":max(0,len(data)-52-metadata)})
    elif len(data)>=52 and data[44:48]==b"PVR!":
        row.update({"version":2,"header_size":struct.unpack_from("<I",data,0)[0],"height":struct.unpack_from("<I",data,4)[0],"width":struct.unpack_from("<I",data,8)[0],"bits_per_pixel":struct.unpack_from("<I",data,12)[0]})
    else:
        row["version"]="unknown"
    rows.append(row)
formats=collections.Counter(str(r.get("format_id",r.get("version"))) for r in rows)
Path("reports").mkdir(exist_ok=True)
Path("reports/pvr-texture-audit.json").write_text(json.dumps({"total_files":len(rows),"total_bytes":sum(r["size_bytes"] for r in rows),"formats":dict(formats),"textures":rows},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"pvr_files":len(rows),"total_bytes":sum(r["size_bytes"] for r in rows),"formats":dict(formats),"sample":rows[:5]},ensure_ascii=False,indent=2))
