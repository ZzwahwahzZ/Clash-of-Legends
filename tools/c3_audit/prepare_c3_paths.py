#!/usr/bin/env python3
import csv, json
from pathlib import Path

source=Path("resource-source-index.csv")
if not source.is_file():
    raise SystemExit("resource-source-index.csv is missing.")
paths=[]
with source.open("r",encoding="utf-8-sig",newline="") as stream:
    for row in csv.DictReader(stream):
        if row.get("category")!="models":
            continue
        source_path=row.get("source_path","")
        staged=row.get("staged_path","")
        if not source_path.lower().endswith(".c3"):
            continue
        if any(ord(char)<32 or ord(char)==127 for char in source_path):
            continue
        if not staged.startswith("resource_stage/models/") or ".." in Path(staged).parts:
            continue
        paths.append(staged)
if not paths:
    raise SystemExit("No clean original C3 model paths were found.")
Path("build").mkdir(parents=True,exist_ok=True)
Path("build/c3-paths.json").write_text(json.dumps(paths,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(f"Prepared {len(paths)} clean C3 model paths.")
