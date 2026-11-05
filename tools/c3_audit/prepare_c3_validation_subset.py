#!/usr/bin/env python3
"""Keep only the reviewed equipment candidates and C3 animation POCs in Godot's import scan."""
import json, shutil
from pathlib import Path

root = Path("build/c3-glb")
full = Path("/tmp/c3-glb-full")
report = json.loads(Path("reports/c3-model-audit.json").read_text(encoding="utf-8"))
family_audit = json.loads(Path("reports/equipment/c3-equipment-family-audit.json").read_text(encoding="utf-8"))
approved_outputs = set()
rejected_outputs = []
for family in family_audit.get("families", []):
    for record in family.get("records", []):
        output = record.get("converted_glb", "")
        if record.get("geometry_gate") == "PASS_BASIC_NONDEGENERATE":
            approved_outputs.add(output)
        else:
            rejected_outputs.append(output)
if not root.is_dir():
    raise SystemExit("Missing complete C3 GLB conversion directory")
if full.exists():
    shutil.rmtree(full)
shutil.move(str(root), str(full))
root.mkdir(parents=True, exist_ok=True)
selected = []
missing = []
for row in report.get("converted", []):
    output = str(row.get("output", ""))
    if not output.startswith("equipment/") or output not in approved_outputs:
        continue
    source = full / output
    destination = root / output
    if not source.is_file():
        missing.append(output)
        continue
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    selected.append(output)
for name in ("motion-poc", "motion-poc-skinned", "motion-poc-vat"):
    source = full / name
    if source.is_dir():
        shutil.copytree(source, root / name)
if missing:
    raise SystemExit(f"Missing equipment GLB candidates: {missing[:20]}")
expected = len(approved_outputs)
if len(selected) != expected:
    raise SystemExit(f"Candidate subset mismatch: copied={len(selected)} expected_geometry_approved={expected}")
summary = {
    "schema_version": "1.0.0",
    "full_conversion_glb_root": str(full),
    "equipment_candidate_count": len(selected),
    "geometry_rejected_candidate_count": len(rejected_outputs),
    "geometry_rejected_candidates": rejected_outputs,
    "equipment_candidates": selected,
    "poc_directories": [name for name in ("motion-poc", "motion-poc-skinned", "motion-poc-vat") if (root / name).exists()],
    "status": "FILTERED_IMPORT_SUBSET_READY",
    "note": "All converted GLBs remain preserved outside the Godot import scan at /tmp/c3-glb-full for this job. Only the 42 equipment candidates and animation POCs are imported to isolate importer instability."
}
out = Path("reports/equipment/c3-validation-subset.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("C3_VALIDATION_SUBSET_OK", len(selected), summary["poc_directories"])
