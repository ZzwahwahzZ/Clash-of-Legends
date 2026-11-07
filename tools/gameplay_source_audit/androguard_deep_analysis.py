#!/usr/bin/env python3
"""Deep, read-only DEX/manifest string and cross-reference extraction for Mobile APKs."""
from __future__ import annotations
import argparse, json, re, sys, zipfile
from pathlib import Path
from androguard.misc import AnalyzeAPK

TERMS = re.compile(
    r"(quest|task|mission|npc|dialog|conversation|objective|reward|accept|complete|turn.?in|"
    r"cq_task|cq_action|taskid|questid|daily|bounty|hunt|trial|event|job|"
    r"مهمة|مهام|مهمات|مكافأة|شخصية|حوار)", re.I
)

def value(obj, name, default=None):
    try:
        v = getattr(obj, name)
        return v() if callable(v) else v
    except Exception:
        return default

def method_name(m):
    return str(value(m, "full_name", None) or m)

def analyze(path: Path):
    apk, dexes, dx = AnalyzeAPK(str(path))
    classes = []
    for c in dx.get_classes():
        classes.append({
            "name": str(value(c, "name", None) or value(c, "get_name", "")),
            "external": bool(value(c, "is_external", False)),
            "method_count": int(value(c, "get_nb_methods", 0) or 0)
        })
    methods = []
    for m in dx.get_methods():
        methods.append({
            "name": method_name(m),
            "external": bool(value(m, "is_external", False)),
            "length": value(m, "get_length", None)
        })
    string_hits = []
    for s in dx.get_strings():
        text = str(value(s, "get_value", "") or "")
        if not text or not TERMS.search(text):
            continue
        refs = []
        try:
            for c, m in s.get_xref_from():
                refs.append({
                    "class": str(value(c, "name", None) or value(c, "get_name", "")),
                    "method": method_name(m)
                })
        except Exception as exc:
            refs.append({"xref_error": f"{type(exc).__name__}: {exc}"})
        string_hits.append({"value": text[:2000], "xref_count": len(refs), "used_by": refs[:100]})
    with zipfile.ZipFile(path) as z:
        members = z.namelist()
        dex_names = [n for n in members if re.fullmatch(r"classes(?:\d+)?\.dex", Path(n).name)]
        native = [n for n in members if n.lower().endswith(".so")]
        resource_candidates = [n for n in members if re.search(r"(quest|task|npc|dialog|mission|reward|action)", n, re.I)]
    return {
        "apk": path.name,
        "package": value(apk, "get_package", ""),
        "version_name": value(apk, "get_androidversion_name", ""),
        "version_code": value(apk, "get_androidversion_code", ""),
        "dex_count_reported": len(dexes),
        "dex_entries": dex_names,
        "class_count": len(classes),
        "method_count": len(methods),
        "classes": classes,
        "methods": methods,
        "quest_task_string_hits": string_hits,
        "native_libraries": native,
        "resource_path_candidates": resource_candidates,
        "permissions": sorted(value(apk, "get_permissions", []) or []),
        "activities": sorted(value(apk, "get_activities", []) or []),
        "services": sorted(value(apk, "get_services", []) or []),
        "receivers": sorted(value(apk, "get_receivers", []) or [])
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk-dir", type=Path, required=True)
    ap.add_argument("--output-dir", type=Path, required=True)
    args = ap.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    paths = sorted(args.apk_dir.glob("*.apk"))
    report = {"tool": "Androguard 4.1.4 AnalyzeAPK + DEX XREF", "apk_count": len(paths), "results": [], "errors": []}
    for path in paths:
        print(f"ANDROGUARD_DEEP_START {path.name}", flush=True)
        try:
            item = analyze(path)
            report["results"].append(item)
            print(f"ANDROGUARD_DEEP_OK {path.name} dex={item['dex_count_reported']} classes={item['class_count']} methods={item['method_count']} task_strings={len(item['quest_task_string_hits'])}", flush=True)
        except Exception as exc:
            report["errors"].append({"apk": path.name, "error": f"{type(exc).__name__}: {exc}"})
            print(f"ANDROGUARD_DEEP_ERROR {path.name}: {type(exc).__name__}: {exc}", flush=True)
    out = args.output_dir / "androguard-deep-analysis.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"apk_count": report["apk_count"], "success_count": len(report["results"]), "error_count": len(report["errors"]), "output": str(out)}, ensure_ascii=False), flush=True)
    if not paths or not report["results"]:
        raise SystemExit(2)

if __name__ == "__main__":
    main()
