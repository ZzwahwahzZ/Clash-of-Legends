#!/usr/bin/env python3
"""Fail CI if the acceptance ledger contains invalid states or unsupported ACCEPTED claims."""
import json
from pathlib import Path

path = Path("quality/acceptance_registry.json")
data = json.loads(path.read_text(encoding="utf-8"))
allowed = {"NOT_ACCEPTED", "NEEDS_SOURCE_ANALYSIS", "IN_PROGRESS", "BLOCKED", "ACCEPTED"}
required = {"source_traceability", "reference_match", "functional_integration",
            "runtime_visual_verification", "automated_tests"}
errors = []
seen = set()
for item in data.get("items", []):
    ident = item.get("id")
    if not ident or ident in seen:
        errors.append(f"missing or duplicate item id: {ident!r}")
    seen.add(ident)
    status = item.get("status")
    if status not in allowed:
        errors.append(f"{ident}: invalid status {status!r}")
    gates = item.get("gates", {})
    if status == "ACCEPTED":
        missing = sorted(k for k in required if gates.get(k) is not True)
        if not isinstance(item.get("evidence"), list) or not item["evidence"]:
            missing.append("evidence[]")
        if missing:
            errors.append(f"{ident}: ACCEPTED without proof: {', '.join(missing)}")
if not data.get("items"):
    errors.append("acceptance registry is empty")
if errors:
    print("ACCEPTANCE LEDGER INVALID")
    print("\n".join(errors))
    raise SystemExit(1)
print(f"ACCEPTANCE LEDGER VALID: {len(data['items'])} tracked areas; no unsupported ACCEPTED claims.")
print("NOTE: CI validates the ledger structure, not visual equivalence; runtime/reference evidence still requires human-reviewed artifacts.")
