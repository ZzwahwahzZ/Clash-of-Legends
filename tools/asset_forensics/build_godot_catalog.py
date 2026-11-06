#!/usr/bin/env python3
"""Promote reviewed assets into a private Godot working copy and build AssetCatalog JSON."""
import argparse, hashlib, json, shutil
from pathlib import Path, PurePosixPath

def safe_path(root, rel):
 p=PurePosixPath(str(rel).replace("\\","/"))
 if p.is_absolute() or not p.parts or any(x in ("..","") for x in p.parts) or (p.parts and ":" in p.parts[0]):
  raise ValueError("unsafe relative path: "+str(rel))
 result=(root/Path(*p.parts)).resolve()
 if root.resolve() not in result.parents and result != root.resolve():
  raise ValueError("path escapes root: "+str(rel))
 return result

def sha(p):
 h=hashlib.sha256()
 with p.open("rb") as f:
  for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
 return h.hexdigest()

def main():
 ap=argparse.ArgumentParser()
 ap.add_argument("project_root",type=Path)
 ap.add_argument("source_root",type=Path)
 ap.add_argument("approved_manifest",type=Path)
 ap.add_argument("--apply",action="store_true",help="copy approved files and write resource_catalog.json")
 a=ap.parse_args()
 project=a.project_root.resolve(); source=a.source_root.resolve()
 manifest=json.loads(a.approved_manifest.read_text(encoding="utf-8"))
 if manifest.get("manifest_version")!=1 or not isinstance(manifest.get("assets"),list):
  raise SystemExit("approved manifest must contain manifest_version=1 and an assets array")
 ids={}; staged=[]; catalog={}
 for item in manifest["assets"]:
  asset_id=str(item.get("id","")).strip()
  if not asset_id or asset_id in ids: raise SystemExit("asset IDs must be non-empty and unique: "+asset_id)
  ids[asset_id]=item
  src=safe_path(source,item.get("source",""))
  dst=safe_path(project,item.get("target",""))
  if not src.is_file(): raise SystemExit("missing source file: "+str(src))
  actual=sha(src); expected=str(item.get("sha256","")).lower()
  if not expected or actual!=expected: raise SystemExit("SHA-256 mismatch or missing for "+asset_id)
  category=str(item.get("category","")).strip()
  if not category: raise SystemExit("missing category for "+asset_id)
  role=str(item.get("asset_role","")).strip()
  if role=="complete_character":
   if item.get("mapping_status")!="verified" or not item.get("character_class") or not item.get("gender"):
    raise SystemExit("complete character requires verified class and gender mapping: "+asset_id)
   if not item.get("rig_id"): raise SystemExit("complete character requires rig_id: "+asset_id)
  staged.append((item,src,dst,category,actual))
 for item,src,dst,category,digest in staged:
  for dependency in item.get("depends_on",[]):
   if dependency not in ids: raise SystemExit("unresolved dependency "+str(dependency)+" for "+str(item["id"]))
  if item.get("rig_id") and item["rig_id"] not in ids:
   raise SystemExit("unresolved rig_id "+str(item["rig_id"])+" for "+str(item["id"]))
  entry={k:v for k,v in item.items() if k not in {"id","source","target","sha256","depends_on"}}
  entry.update({"id":item["id"],"path":str(safe_path(project,item["target"]).relative_to(project)).replace("\\","/"),
                "extension":Path(item["target"]).suffix.lower(),"sha256":digest,
                "depends_on":item.get("depends_on",[])})
  catalog.setdefault(category,[]).append(entry)
 output={"catalog_version":1,"assets":catalog,"integration_asset_count":len(staged)}
 catalog_path=project/"resource_stage/world/resource_catalog.json"
 if a.apply:
  for item,src,dst,category,digest in staged:
   dst.parent.mkdir(parents=True,exist_ok=True)
   if dst.exists() and sha(dst)!=digest: raise SystemExit("refusing to overwrite different existing asset: "+str(dst))
   if not dst.exists(): shutil.copy2(src,dst)
  catalog_path.parent.mkdir(parents=True,exist_ok=True)
  catalog_path.write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({"mode":"apply" if a.apply else "dry-run","asset_count":len(staged),
                   "categories":{k:len(v) for k,v in catalog.items()},
                   "catalog_path":str(catalog_path),"assets":[{"id":i["id"],"target":str(d.relative_to(project))} for i,s,d,c,h in staged]},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
