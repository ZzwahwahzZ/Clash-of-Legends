#!/usr/bin/env python3
import collections,json,struct
from pathlib import Path

rows=[]
for path in sorted(Path("build/pvr-source").rglob("*.pvr")):
    data=path.read_bytes()
    row={"path":path.relative_to("build/pvr-source").as_posix(),"size_bytes":len(data),"magic":data[:4].hex()}
    if len(data)>=52 and data[44:48]==b"PVR!":
        header_size,height,width,num_mipmaps,flags,data_size,bpp,rmask,gmask,bmask,amask,magic,surfaces=struct.unpack_from("<13I",data,0)
        row.update({"version":2,"header_size":header_size,"height":height,"width":width,"num_mipmaps":num_mipmaps,"flags":flags,"data_size":data_size,"bits_per_pixel":bpp,"red_mask":rmask,"green_mask":gmask,"blue_mask":bmask,"alpha_mask":amask,"magic_ascii":data[44:48].decode("ascii",errors="replace"),"surfaces":surfaces,"payload_bytes":len(data)-header_size})
    elif len(data)>=52 and data[:4]==b"PVR\x03":
        pixel_format=struct.unpack_from("<Q",data,8)[0]
        color_space,channel_type,height,width,depth,surfaces,faces,mips,metadata=struct.unpack_from("<9I",data,16)
        row.update({"version":3,"pixel_format":pixel_format,"format_id":pixel_format&0xffffffff,"color_space":color_space,"channel_type":channel_type,"width":width,"height":height,"depth":depth,"surfaces":surfaces,"faces":faces,"mipmaps":mips,"metadata_bytes":metadata,"data_offset":52+metadata,"payload_bytes":max(0,len(data)-52-metadata)})
    else:
        row["version"]="unknown"
    rows.append(row)
formats=collections.Counter(str(r.get("bits_per_pixel",r.get("format_id",r.get("version")))) for r in rows)
Path("reports").mkdir(exist_ok=True)
Path("reports/pvr-texture-audit.json").write_text(json.dumps({"total_files":len(rows),"total_bytes":sum(r["size_bytes"] for r in rows),"formats":dict(formats),"textures":rows},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"pvr_files":len(rows),"total_bytes":sum(r["size_bytes"] for r in rows),"formats":dict(formats),"sample":rows[:5]},ensure_ascii=False,indent=2))
