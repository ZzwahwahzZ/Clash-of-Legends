#!/usr/bin/env python3
"""Safe recursive game-asset archive inventory/extraction. Standard library first."""
from __future__ import annotations
import argparse, collections, hashlib, json, shutil, stat, subprocess, sys, tarfile, zipfile
from pathlib import Path, PurePosixPath

KEYWORDS = {
 "skeleton": ("skeleton","bone","rig","3dskeleton","3dobjprop","rolepart"),
 "motion": ("motion","anim","action",".ani",".moti"),
 "model": ("model","mesh","role","monster","npc","mount","weapon","body"),
 "texture": ("texture","atlas","sprite","image","material"),
 "ui": ("interface","ui/","ui_","fui","layout","font"),
 "audio": ("audio","sound","music","voice","effect","sfx"),
 "game_data": ("quest","task","item","drop","monster","npc","skill","magic","map","teleport"),
}
ARCHIVE_EXT={".zip",".apk",".obb",".jar",".tar",".tgz",".gz",".bz2",".xz",".7z",".rar",".pak",".pck"}
MAX_FILE=2*1024**3
MAX_TOTAL=20*1024**3

def sha256_file(p):
 h=hashlib.sha256()
 with p.open("rb") as f:
  for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
 return h.hexdigest()

def safe_rel(name):
 p=PurePosixPath(name.replace("\\\\","/"))
 if p.is_absolute() or any(x in ("..","") for x in p.parts) or (p.parts and ":" in p.parts[0]):
  raise ValueError("unsafe archive path: "+repr(name))
 return Path(*p.parts)

def classify(name):
 low=name.lower().replace("\\\\","/")
 return [k for k,terms in KEYWORDS.items() if any(t in low for t in terms)]

def signature(p):
 try:
  with p.open("rb") as f: b=f.read(16)
 except OSError: return "unreadable"
 for magic,label in [(b"PK\\x03\\x04","zip"),(b"7z\\xbc\\xaf\\x27\\x1c","7z"),(b"Rar!","rar"),(b"UnityFS","unityfs"),(b"GDPC","godot_pck"),(b"\\x7fELF","elf"),(b"OggS","ogg"),(b"RIFF","riff"),(b"DDS ","dds"),(b"\\x89PNG","png"),(b"\\xff\\xd8\\xff","jpeg"),(b"glTF","gltf_binary")]:
  if b.startswith(magic): return label
 return "unknown"

def record(records,scope,name,size,crc=None):
 r={"scope":scope or "root","path":name,"size_bytes":size,"sha256":None,"categories":classify((scope+"/" if scope else "")+name),"extension":Path(name).suffix.lower(),"signature":None}
 if crc is not None: r["crc32"]=f"{crc:08x}"
 records.append(r); return r

def extract_zip(zf,dest,scope,records,limit):
 out=[]
 for i in zf.infolist():
  if i.is_dir(): continue
  rel=safe_rel(i.filename); mode=(i.external_attr>>16)&0xffff
  if stat.S_ISLNK(mode): continue
  if i.file_size>MAX_FILE or limit[0]+i.file_size>MAX_TOTAL: raise RuntimeError("extraction size limit exceeded: "+i.filename)
  target=dest/rel; target.parent.mkdir(parents=True,exist_ok=True); h=hashlib.sha256()
  with zf.open(i) as src,target.open("wb") as dst:
   while True:
    b=src.read(1024*1024)
    if not b: break
    dst.write(b); h.update(b)
  limit[0]+=i.file_size; r=record(records,scope,i.filename,i.file_size,i.CRC); r["sha256"]=h.hexdigest(); r["signature"]=signature(target); out.append(target)
 return out

def extract_tar(tf,dest,scope,records,limit):
 out=[]
 for i in tf.getmembers():
  if not i.isfile(): continue
  rel=safe_rel(i.name)
  if i.size>MAX_FILE or limit[0]+i.size>MAX_TOTAL: raise RuntimeError("extraction size limit exceeded: "+i.name)
  src=tf.extractfile(i)
  if src is None: continue
  target=dest/rel; target.parent.mkdir(parents=True,exist_ok=True); h=hashlib.sha256()
  with src,target.open("wb") as dst:
   while True:
    b=src.read(1024*1024)
    if not b: break
    dst.write(b); h.update(b)
  limit[0]+=i.size; r=record(records,scope,i.name,i.size); r["sha256"]=h.hexdigest(); r["signature"]=signature(target); out.append(target)
 return out

def external_list(p):
 tool=shutil.which("7z") or shutil.which("7zz")
 if tool: cmd=[tool,"l","-slt",str(p)]
 else:
  tool=shutil.which("bsdtar")
  if not tool: return {"tool":None,"returncode":None,"listing":"","stderr":"Install p7zip-full or libarchive-tools."}
  cmd=[tool,"-tvf",str(p)]
 q=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
 return {"tool":tool,"returncode":q.returncode,"listing":q.stdout[-80000:],"stderr":q.stderr[-8000:]}

def main():
 a=argparse.ArgumentParser()
 a.add_argument("archive",type=Path); a.add_argument("--out",type=Path,required=True); a.add_argument("--max-depth",type=int,default=5)
 x=a.parse_args(); src=x.archive.expanduser().resolve()
 if not src.is_file(): a.error("archive not found: "+str(src))
 out=x.out.expanduser().resolve(); stage=out/"extracted"; stage.mkdir(parents=True,exist_ok=True)
 report={"source_name":src.name,"source_bytes":src.stat().st_size,"source_sha256":sha256_file(src),"archives":[],"files":[],"external_format_listings":[],"errors":[]}
 limit=[0]; queue=[(src,stage/"root",0,"")]; seen=set()
 while queue:
  cur,dest,depth,scope=queue.pop(0)
  try:
   sig=signature(cur)
   if sig=="zip":
    with zipfile.ZipFile(cur) as z:
     bad=z.testzip()
     if bad: raise RuntimeError("ZIP CRC failure: "+bad)
     report["archives"].append({"path":str(cur),"format":"zip","entries":len(z.infolist()),"test":"passed"})
     children=extract_zip(z,dest,scope,report["files"],limit)
   elif cur.suffix.lower() in {".tar",".tgz",".gz",".bz2",".xz"}:
    with tarfile.open(cur,"r:*") as t:
     report["archives"].append({"path":str(cur),"format":"tar","entries":len(t.getmembers()),"test":"readable"})
     children=extract_tar(t,dest,scope,report["files"],limit)
   else:
    listing=external_list(cur); report["external_format_listings"].append({"path":str(cur),"signature":sig,**listing})
    report["archives"].append({"path":str(cur),"format":sig,"test":"external-list-only"}); children=[]
   for child in children:
    if child.suffix.lower() in ARCHIVE_EXT and depth<x.max_depth and child not in seen:
     seen.add(child); queue.append((child,dest/(child.stem+"_contents"),depth+1,str(child.relative_to(stage))))
  except Exception as e: report["errors"].append({"path":str(cur),"error":str(e)})
 report["file_count"]=len(report["files"]); report["extracted_bytes"]=limit[0]
 report["category_counts"]={k:sum(k in f["categories"] for f in report["files"]) for k in KEYWORDS}
 report["extension_counts"]=dict(collections.Counter(f["extension"] or "[none]" for f in report["files"]))
 report["next_stage"]={"skeleton_motion":"validate record boundaries, bone names, parent IDs, pivots, sockets and animation tracks before parser promotion","models":"convert validated geometry to GLB with armature and clips preserved","textures":"identify pixel format, dimensions, alpha and color space before conversion","audio":"probe codec, duration, channels and sample rate with ffprobe","ui":"map FUI/layout/atlas/config references into screen dependencies","gameplay":"validate item/quest/NPC/monster table schemas before importing"}
 (out/"forensic-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 with (out/"resource-candidates.csv").open("w",encoding="utf-8") as f:
  f.write("scope,path,size_bytes,extension,signature,categories,sha256\n")
  for r in report["files"]:
   vals=[r.get(k,"") for k in ("scope","path","size_bytes","extension","signature")]
   f.write(",".join('"'+str(v).replace('"','""')+'"' for v in vals)+',"'+ ";".join(r["categories"])+'","'+str(r.get("sha256") or "")+'"\n')
 print(json.dumps({k:report[k] for k in ("source_name","source_bytes","source_sha256","archives","file_count","extracted_bytes","category_counts","extension_counts","errors")},ensure_ascii=False,indent=2))
 return 1 if report["errors"] else 0
if __name__=="__main__": sys.exit(main())
