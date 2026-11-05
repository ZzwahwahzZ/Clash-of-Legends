#!/usr/bin/env python3
"""Fail CI on incomplete or unsupported source/reference asset acceptance claims."""
import json
from pathlib import Path

path = Path("quality/acceptance_registry.json")
data = json.loads(path.read_text(encoding="utf-8"))
allowed = {"NOT_ACCEPTED", "NEEDS_SOURCE_ANALYSIS", "IN_PROGRESS", "BLOCKED", "ACCEPTED"}
required = {
    "source_traceability", "reference_match", "functional_integration",
    "runtime_visual_verification", "automated_tests", "device_performance",
}
required_ids = {
    "class_trojan", "class_warrior", "class_archer", "class_ninja", "class_monk",
    "class_pirate", "class_dragonwarrior", "class_windwalker", "class_thunderstriker",
    "class_watertaoist", "class_firetaoist", "mounts_and_riding_equipment",
    "helmets_and_headgear", "armor_and_body_gear", "weapons_all_families",
    "fashion_garments_capes_wings", "paid_and_premium_equipment",
    "mount_tack_saddles_ornaments",
}
errors = []
seen = set()
items = data.get("items", [])
for item in items:
    ident = item.get("id")
    if not ident or ident in seen:
        errors.append(f"missing or duplicate item id: {ident!r}")
    seen.add(ident)
    status = item.get("status")
    if status not in allowed:
        errors.append(f"{ident}: invalid status {status!r}")
    gates = item.get("gates", {})
    if not isinstance(gates, dict):
        errors.append(f"{ident}: gates must be an object")
        gates = {}
    if status == "ACCEPTED":
        missing = sorted(k for k in required if gates.get(k) is not True)
        evidence = item.get("evidence")
        if not isinstance(evidence, list) or not evidence or not all(isinstance(x, str) and x.strip() for x in evidence):
            missing.append("evidence[]")
        if missing:
            errors.append(f"{ident}: ACCEPTED without proof: {', '.join(missing)}")
    if status in {"BLOCKED", "NEEDS_SOURCE_ANALYSIS", "NOT_ACCEPTED"} and all(gates.get(k) is True for k in required):
        errors.append(f"{ident}: status conflicts with all acceptance gates marked true")
missing_ids = sorted(required_ids - seen)
if missing_ids:
    errors.append("missing mandatory asset coverage: " + ", ".join(missing_ids))
if not items:
    errors.append("acceptance registry is empty")
if errors:
    print("ACCEPTANCE LEDGER INVALID")
    print("\n".join(errors))
    raise SystemExit(1)
print(f"ACCEPTANCE LEDGER VALID: {len(items)} tracked areas; all 11 classes, mounts and equipment families are explicitly covered.")
print("No unsupported ACCEPTED claims. ACCEPTED requires provenance, reference match, functional integration, visual review, automated tests, target-device performance and retained evidence.")
