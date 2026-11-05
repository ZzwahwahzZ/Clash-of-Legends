#!/usr/bin/env python3
import csv, json
from pathlib import Path

source=Path("resource-source-index.csv")
if not source.is_file():
    raise SystemExit("resource-source-index.csv is missing.")
c3_paths=[]
pvr_paths=[]
with source.open("r",encoding="utf-8-sig",newline="") as stream:
    for row in csv.DictReader(stream):
        category=row.get("category","")
        source_path=row.get("source_path","")
        staged=row.get("staged_path","")
        if any(ord(char)<32 or ord(char)==127 for char in source_path):
            continue
        if ".." in Path(staged).parts:
            continue
        lower=source_path.lower()
        if category=="models" and lower.endswith(".c3") and staged.startswith("resource_stage/models/"):
            c3_paths.append(staged)
        if category=="maps" and lower.endswith(".pvr") and "/c3/" in lower and "/c3/effect/" not in lower and staged.startswith("resource_stage/maps/"):
            pvr_paths.append(staged)
if not c3_paths:
    raise SystemExit("No clean original C3 model paths were found.")
if not pvr_paths:
    raise SystemExit("No C3-related PVR texture paths were found.")
Path("build").mkdir(parents=True,exist_ok=True)
Path("build/c3-paths.json").write_text(json.dumps(c3_paths,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
Path("build/pvr-paths.json").write_text(json.dumps(pvr_paths,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(f"Prepared {len(c3_paths)} C3 model paths and {len(pvr_paths)} C3 PVR texture paths.")
