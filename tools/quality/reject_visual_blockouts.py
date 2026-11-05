#!/usr/bin/env python3
"""Reject primitive placeholder geometry in critical player/world scenes."""
from pathlib import Path
import sys

SCENES = {
    "scenes/characters/Player.tscn": "player character",
    "scenes/characters/SimulatedPlayer.tscn": "simulated character",
    "scenes/core/MainGame.tscn": "main world",
}
PLACEHOLDERS = ("BoxMesh", "SphereMesh", "CylinderMesh", "PrismMesh", "CapsuleMesh", "QuadMesh", "PlaneMesh")
failures = []
for scene, role in SCENES.items():
    path = Path(scene)
    if not path.is_file():
        failures.append(f"{scene}: required scene is missing")
        continue
    lines = path.read_text(encoding="utf-8").splitlines()
    found = sorted({name for name in PLACEHOLDERS if any(line.startswith("[sub_resource ") and ('type="' + name + '"' in line) for line in lines)})
    if found:
        kinds = ", ".join(found)
        failures.append(f"{scene} ({role}): primitive placeholder render meshes: {kinds}")
if failures:
    print("VISUAL BLOCKOUT GATE: FAILED")
    for item in failures:
        print(" - " + item)
    print("Replace blockout meshes with approved production assets and rerun visual capture review.")
    sys.exit(1)
print("VISUAL BLOCKOUT GATE: PASSED — no primitive placeholders in critical scenes")
