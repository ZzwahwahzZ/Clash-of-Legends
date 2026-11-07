#!/usr/bin/env python3
"""Preserve the complete C3 conversion while importing only the reviewed skeletal and animation proof set."""
from pathlib import Path
import json
import shutil

root = Path("build/c3-glb")
full = Path("/tmp/c3-glb-full")
report_path = Path("reports/c3-model-audit.json")
if not root.is_dir():
    raise SystemExit("Missing complete C3 conversion output.")
if not report_path.is_file():
    raise SystemExit("Missing C3 source audit report.")
report = json.loads(report_path.read_text(encoding="utf-8"))
required = ("motion-poc", "motion-poc-skinned", "motion-poc-vat", "skeleton-poc")
if full.exists():
    shutil.rmtree(full)
shutil.move(str(root), str(full))
root.mkdir(parents=True, exist_ok=True)
counts = {}
missing = []
for name in required:
    source = full / name
    if not source.is_dir():
        missing.append(name)
        continue
    destination = root / name
    shutil.copytree(source, destination)
    counts[name] = sum(1 for p in destination.rglob("*") if p.is_file())
if missing:
    raise SystemExit("Missing required C3 proof directories: " + ", ".join(missing))
expected_skeletons = int(report.get("skeleton_catalog_poc_count", 0))
actual_skeletons = sum(1 for p in (root / "skeleton-poc").rglob("*.glb"))
if expected_skeletons <= 0 or actual_skeletons != expected_skeletons:
    raise SystemExit(f"Skeleton proof subset mismatch: expected={expected_skeletons} actual={actual_skeletons}")
expected_clips = sum(1 for row in report.get("external_motion_poc", []) if row.get("status") == "EXPORTED_PENDING_GODOT_IMPORT_VALIDATION")
actual_clips = sum(1 for p in (root / "motion-poc").glob("*.glb"))
if actual_clips != expected_clips:
    raise SystemExit(f"Animation proof subset mismatch: expected={expected_clips} actual={actual_clips}")
payload = {
    "schema_version": "1.0.0",
    "full_conversion_root": str(full),
    "full_converted_glb_count": sum(1 for p in full.rglob("*.glb")),
    "import_subset": counts,
    "skeleton_catalog_expected": expected_skeletons,
    "skeleton_catalog_imported": actual_skeletons,
    "animation_clips_expected": expected_clips,
    "animation_clips_imported": actual_clips,
    "status": "SKELETAL_AND_ANIMATION_PROOF_SUBSET_READY",
    "note": "All converted outputs remain preserved in /tmp/c3-glb-full; only the skeletal catalog and every exact-signature full-character motion proof resource enter Godot's importer in this phase."
}
Path("reports").mkdir(exist_ok=True)
Path("reports/c3-import-subset.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("C3_IMPORT_SUBSET_READY", json.dumps(payload, ensure_ascii=False))
