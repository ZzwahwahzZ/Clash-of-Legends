#!/usr/bin/env python3
"""Audit whether source-image/model coverage exists for each equipment family.

This is an evidence gate, not an importer: a generic equipment image is never
counted as a helmet, armor, shield, accessory, or weapon without a classified
source record. The reference archive is currently known to contain only one
unclassified equipment reference.
"""
from __future__ import annotations
import argparse, csv, json
from collections import Counter
from pathlib import Path

EXPECTED = {
    "headgear": ["helmet", "helm", "headgear", "cap", "coronet", "hood", "hat", "headband", "plume", "veil"],
    "armor": ["armor", "armour", "robe", "coat", "vest", "frock", "suit"],
    "shield": ["shield"],
    "one_handed_weapon": ["blade", "backsword", "hook", "whip", "axe", "hammer", "club", "scepter", "dagger", "arrow", "sword", "katana", "bead", "rapier", "pistol", "throwing knife", "nunchaku"],
    "two_handed_weapon": ["glaive", "poleaxe", "long hammer", "spear", "wand", "halbert", "pickaxe", "hoe", "bow", "scythe"],
    "accessory": ["earring", "necklace", "bracelet", "ring", "bag", "riding crop"],
    "mount": ["mount", "saddle", "mount armor", "mount armour"],
    "garment": ["garment", "fashion", "costume"],
    "talisman_and_special": ["talisman", "fan", "tower", "refinery", "dragon soul", "martial soul", "weapon accessory"],
}

def classify(label: str) -> str:
    s = label.lower().replace("_", " ").replace("-", " ")
    matches = [family for family, terms in EXPECTED.items() if any(t in s for t in terms)]
    return matches[0] if len(matches) == 1 else ("ambiguous" if matches else "unclassified")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest", type=Path)
    ap.add_argument("--project-root", type=Path, default=Path("."))
    ap.add_argument("--output", type=Path, default=Path("reports/equipment/equipment_coverage_audit.json"))
    args = ap.parse_args()
    rows = list(csv.DictReader(args.manifest.open(encoding="utf-8-sig", newline="")))
    counts = Counter()
    records = []
    for row in rows:
        category = (row.get("category") or "").strip().lower()
        file = (row.get("file") or "").strip()
        family = classify(category + " " + Path(file).stem)
        counts[family] += 1
        records.append({
            "source_category": category, "file": file, "family": family,
            "source_url": row.get("source_url", ""),
            "source_hash": row.get("sha256", ""),
            "source_present_in_project": (args.project_root / file).is_file(),
        })
    coverage = []
    for family in EXPECTED:
        n = counts[family]
        coverage.append({
            "family": family, "classified_source_records": n,
            "status": "SOURCE_COVERAGE_PRESENT_REQUIRES_VISUAL_REVIEW" if n else "MISSING_SOURCE_REFERENCE",
        })
    result = {
        "status": "BLOCKED_INCOMPLETE_EQUIPMENT_SOURCE_COVERAGE" if any(x["classified_source_records"] == 0 for x in coverage) else "SOURCE_COVERAGE_PRESENT_REQUIRES_VISUAL_REVIEW",
        "manifest": str(args.manifest), "source_record_count": len(rows),
        "classified_counts": dict(counts), "coverage": coverage, "records": records,
        "policy": "No model is approved by this inventory. Source identity, exact item mapping, geometry, UV/material quality, rig/socket fit, runtime appearance and performance require separate evidence.",
        "taxonomy_note": "Reference taxonomy is informed by classic Conquer item indexes; it is not proof of Conquer Mobile 1.1.2.3 parity."
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(result["status"], "records=", len(rows))
    for x in coverage: print(x["family"], x["classified_source_records"], x["status"])

if __name__ == "__main__":
    main()
