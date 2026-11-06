#!/usr/bin/env python3
"""Inspect standard media and convert standard 3D interchange files to GLB."""
import argparse, hashlib, json, shutil, subprocess, tempfile
from pathlib import Path

MODEL_EXT={".fbx",".dae",".obj",".blend"}
IMAGE_EXT={".png",".jpg",".jpeg",".webp",".tga",".bmp",".dds"}
AUDIO_EXT={".ogg",".wav",".mp3",".flac",".opus",".m4a",".aac"}

def sha(p):
 h=hashlib.sha256()
 with p.open("rb") as f:
  for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
 return h.hexdigest()

def blender_convert(blender,src,dst):
 helper=dst.parent/"_blender_import_export.py"
 helper.write_text(r'''
import bpy, os, sys
args=sys.argv[sys.argv.index("--")+1:]
src,dst=args[0],args[1]
ext=os.path.splitext(src)[1].lower()
if ext==".blend":
    bpy.ops.wm.open_mainfile(filepath=src)
else:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    if ext==".fbx": bpy.ops.import_scene.fbx(filepath=src)
    elif ext==".dae": bpy.ops.wm.collada_import(filepath=src)
    elif ext==".obj":
        if hasattr(bpy.ops.wm,"obj_import"): bpy.ops.wm.obj_import(filepath=src)
        else: bpy.ops.import_scene.obj(filepath=src)
    else: raise RuntimeError("unsupported input extension: "+ext)
bpy.ops.export_scene.gltf(filepath=dst,export_format="GLB",export_animations=True,export_skins=True,export_morph=True)
''',encoding="utf-8")
 p=subprocess.run([blender,"--background","--factory-startup","--python",str(helper),"--",str(src),str(dst)],capture_output=True,text=True,timeout=900)
 helper.unlink(missing_ok=True)
 if p.returncode!=0 or not dst.is_file() or dst.stat().st_size==0:
  raise RuntimeError((p.stderr or p.stdout)[-5000:] or "Blender conversion failed")
 return p.stdout[-2000:]

def main():
 ap=argparse.ArgumentParser()
 ap.add_argument("source_root",type=Path); ap.add_argument("--out",type=Path,required=True); ap.add_argument("--max-models",type=int,default=250)
 a=ap.parse_args(); root=a.source_root.resolve(); out=a.out.resolve(); out.mkdir(parents=True,exist_ok=True)
 blender=shutil.which("blender"); ffprobe=shutil.which("ffprobe")
 report={"source_root":str(root),"blender":blender,"ffprobe":ffprobe,"models":[],"audio":[],"images":[],"errors":[]}
 models=sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in MODEL_EXT)
 for src in models[:a.max_models]:
  item={"source":str(src.relative_to(root)),"source_bytes":src.stat().st_size,"source_sha256":sha(src),"status":"not-converted"}
  if not blender:
   item["reason"]="Blender is not installed"; report["models"].append(item); continue
  dst=out/"models"/(src.stem+".glb"); dst.parent.mkdir(parents=True,exist_ok=True)
  if dst.exists(): dst=dst.with_name(src.stem+"_"+item["source_sha256"][:8]+".glb")
  try:
   log=blender_convert(blender,src,dst)
   item.update({"status":"converted","output":str(dst),"output_bytes":dst.stat().st_size,"output_sha256":sha(dst),"blender_log_tail":log})
  except Exception as e:
   item.update({"status":"failed","error":str(e)})
  report["models"].append(item)
 for src in sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in AUDIO_EXT):
  item={"source":str(src.relative_to(root)),"bytes":src.stat().st_size,"sha256":sha(src)}
  if ffprobe:
   q=subprocess.run([ffprobe,"-v","error","-show_entries","format=duration,format_name:stream=codec_name,codec_type,sample_rate,channels,channel_layout","-of","json",str(src)],capture_output=True,text=True,timeout=120)
   if q.returncode==0:
    try: item["probe"]=json.loads(q.stdout)
    except Exception: item["probe_error"]="ffprobe returned invalid JSON"
   else: item["probe_error"]=q.stderr[-2000:]
  else: item["probe_error"]="ffprobe not installed"
  report["audio"].append(item)
 try:
  from PIL import Image
  for src in sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXT):
   item={"source":str(src.relative_to(root)),"bytes":src.stat().st_size,"sha256":sha(src)}
   try:
    with Image.open(src) as im: item.update({"format":im.format,"width":im.width,"height":im.height,"mode":im.mode,"frames":getattr(im,"n_frames",1)})
   except Exception as e: item["inspect_error"]=str(e)
   report["images"].append(item)
 except ImportError: report["image_inspection"]="Install Pillow for image dimensions and mode."
 report["model_count"]=len(report["models"]); report["converted_model_count"]=sum(x["status"]=="converted" for x in report["models"])
 report["audio_count"]=len(report["audio"]); report["image_count"]=len(report["images"])
 (out/"media-integration-manifest.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({k:report[k] for k in ("blender","ffprobe","model_count","converted_model_count","audio_count","image_count","errors")},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
