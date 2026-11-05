#!/usr/bin/env python3
"""Prepare deduplicated, category-separated source assets for Godot PCK export."""
import csv, hashlib, json, os, re, shutil, sys, zipfile
from pathlib import Path

ROOT=Path.cwd()
STAGE=ROOT/"resource_stage"
SOURCE=ROOT/"build/source_archives"
shutil.rmtree(STAGE,ignore_errors=True)
STAGE.mkdir(parents=True,exist_ok=True)
if not SOURCE.is_dir(): raise SystemExit(f"Source archive directory does not exist: {SOURCE}")

ARCHIVES=[
 ("extracted-assets-001.zip","https://github.com/ZzwahwahzZ/Conquer-Mobile-Assets./releases/download/mobile-extracted-assets/extracted-assets-001.zip"),
 ("conquer-mobile-prepared-assets.zip","https://github.com/ZzwahwahzZ/Conquer-Mobile-Assets./releases/download/mobile-extracted-assets/conquer-mobile-prepared-assets.zip"),
 ("conquer-mobile-supplemental-assets.zip","https://github.com/ZzwahwahzZ/Conquer-Mobile-Assets./releases/download/mobile-extracted-assets/conquer-mobile-supplemental-assets.zip"),
]
EXTS={".glb",".gltf",".obj",".fbx",".dae",".blend",".tscn",".tres",".res",".scn",".png",".jpg",".jpeg",".webp",".tga",".bmp",".ktx",".ktx2",".dds",".ogg",".wav",".mp3",".flac",".ttf",".otf",".fnt",".json",".tres",".material",".shader",".gdshader",".cfg",".xml",".ini",".bin",".dat"}
RULES=[
 ("audio",re.compile(r"audio|sound|music|voice|\.ogg$|\.wav$|\.mp3$",re.I)),
 ("maps",re.compile(r"map|terrain|scene|world|city|village|dungeon|\.height|\.terrain",re.I)),
 ("characters",re.compile(r"character|player|role|human|body|hair|face|\.skel|skeleton",re.I)),
 ("monsters",re.compile(r"monster|mob|creature|beast|boss|npc_enemy",re.I)),
 ("equipment",re.compile(r"weapon|armor|armour|equip|sword|bow|dagger|staff|shield|helmet|boot|glove",re.I)),
 ("mounts",re.compile(r"mount|horse|pet|ride|dragon",re.I)),
 ("effects",re.compile(r"effect|particle|skill|spell|magic|vfx|fx|trail|projectile",re.I)),
]
seen=set(); rows=[]; totals={}; extension_counts={}; archive_entry_counts={}; unsupported=[]
for archive_name,_ in ARCHIVES:
    archive=SOURCE/archive_name
    if not archive.exists(): raise SystemExit(f"Missing downloaded archive: {archive}")
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            if info.is_dir(): continue
            raw=info.filename.replace("\\","/")
            parts=[x for x in raw.split("/") if x not in ("",".","..")]
            if not parts: continue
            name=parts[-1]
            ext=Path(name).suffix.lower() or "[no-extension]"
            extension_counts[ext]=extension_counts.get(ext,0)+1
            archive_entry_counts[archive_name]=archive_entry_counts.get(archive_name,0)+1
            if ext not in EXTS:
                unsupported.append({"archive":archive_name,"path":raw,"extension":ext,"size_bytes":info.file_size})
                continue
            if any(x.startswith(".") for x in parts): continue
            # Stable content hash deduplication across the three source bundles.
            digest=hashlib.sha256()
            with z.open(info) as src:
                while True:
                    b=src.read(1024*1024)
                    if not b: break
                    digest.update(b)
            sha=digest.hexdigest()
            if sha in seen: continue
            seen.add(sha)
            rel="/".join(parts)
            category="world"
            for cat,rx in RULES:
                if rx.search(rel): category=cat; break
            safe=re.sub(r"[^A-Za-z0-9._/-]+","_",rel).lstrip("/")
            dest=STAGE/category/safe
            dest.parent.mkdir(parents=True,exist_ok=True)
            with z.open(info) as src, open(dest,"wb") as out: shutil.copyfileobj(src,out,1024*1024)
            rows.append({"category":category,"source_archive":archive_name,"source_path":raw,"staged_path":dest.relative_to(ROOT).as_posix(),"size_bytes":info.file_size,"sha256":sha})
            totals[category]=totals.get(category,0)+1
reports=ROOT/"reports"
reports.mkdir(parents=True,exist_ok=True)
with open(reports/"resource-source-index.csv","w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=["category","source_archive","source_path","staged_path","size_bytes","sha256"]);w.writeheader();w.writerows(rows)
audit={"archive_entry_counts":archive_entry_counts,"extension_counts":dict(sorted(extension_counts.items())),"unsupported_files":unsupported,"unique_supported_files":len(rows),"category_counts":totals,"staged_bytes":sum(x["size_bytes"] for x in rows)}
(reports/"source-archive-extension-audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(audit,ensure_ascii=False,indent=2))
if not rows: raise SystemExit("No compatible asset files found; refusing to publish empty packs.")
