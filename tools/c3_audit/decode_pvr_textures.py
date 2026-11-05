#!/usr/bin/env python3
import json,struct
from pathlib import Path
from PIL import Image

def channel(value,mask):
    if mask==0: return 255
    shift=(mask & -mask).bit_length()-1
    bits=mask.bit_count()
    raw=(value & mask)>>shift
    maximum=(1<<bits)-1
    return (raw*255+maximum//2)//maximum

decoded=[]
failed=[]
root=Path("build/pvr-source")
out=Path("build/pvr-png")
for path in sorted(root.rglob("*.pvr")):
    data=path.read_bytes()
    try:
        if len(data)<52 or data[44:48]!=b"PVR!":
            raise ValueError("unsupported PVR header")
        header_size,height,width,mips,flags,data_size,bpp,rmask,gmask,bmask,amask,magic,surfaces=struct.unpack_from("<13I",data,0)
        if header_size<52 or header_size>len(data) or width<1 or height<1:
            raise ValueError("invalid dimensions or header size")
        if bpp not in (16,24,32):
            raise ValueError(f"unsupported pixel depth {bpp}")
        bytes_per_pixel=bpp//8
        needed=width*height*bytes_per_pixel
        start=header_size
        end=start+needed
        if end>len(data) or (data_size and data_size<needed):
            raise ValueError("pixel payload is truncated")
        pixels=data[start:end]
        rgba=bytearray(width*height*4)
        for i in range(width*height):
            chunk=pixels[i*bytes_per_pixel:(i+1)*bytes_per_pixel]
            value=int.from_bytes(chunk,"little")
            rgba[i*4+0]=channel(value,rmask)
            rgba[i*4+1]=channel(value,gmask)
            rgba[i*4+2]=channel(value,bmask)
            rgba[i*4+3]=channel(value,amask)
        image=Image.frombytes("RGBA",(width,height),bytes(rgba))
        relative=path.relative_to(root).with_suffix(".png")
        destination=out/relative
        destination.parent.mkdir(parents=True,exist_ok=True)
        image.save(destination,optimize=True)
        decoded.append({"source":path.relative_to(root).as_posix(),"png":destination.relative_to(out).as_posix(),"width":width,"height":height,"bits_per_pixel":bpp,"bytes":len(data)})
    except Exception as error:
        failed.append({"path":path.relative_to(root).as_posix(),"error":str(error)})
report={"decoded":len(decoded),"failed":len(failed),"textures":decoded,"errors":failed}
Path("reports/pvr-decode-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"decoded":len(decoded),"failed":len(failed),"sample":decoded[:5],"errors":failed[:10]},ensure_ascii=False,indent=2))
if not decoded:
    raise SystemExit("No PVR textures were decoded.")
