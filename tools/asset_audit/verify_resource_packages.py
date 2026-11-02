#!/usr/bin/env python3
"""Verify the four optional Clash of Legends resource packages.

This tool never creates placeholder packages and never modifies game files.
It checks existence, exact byte size, and SHA-256 against RESOURCE_MANIFEST.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


def load_manifest(path: Path) -> dict:
    # RESOURCE_MANIFEST is JSON preceded by human-readable # comment lines.
    lines = [line for line in path.read_text(encoding="utf-8").splitlines()
             if not line.lstrip().startswith("#")]
    return json.loads("\n".join(lines))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(),
                        help="Project root (defaults to current directory)")
    parser.add_argument("--manifest", type=Path, default=None,
                        help="Manifest path (defaults to ROOT/RESOURCE_MANIFEST)")
    args = parser.parse_args()

    root = args.root.resolve()
    manifest_path = (args.manifest or root / "RESOURCE_MANIFEST").resolve()
    if not manifest_path.is_file():
        print(f"ERROR: manifest not found: {manifest_path}")
        return 2

    manifest = load_manifest(manifest_path)
    packages = manifest.get("resource_packages", [])
    if len(packages) != 4:
        print(f"WARNING: expected 4 resource packages; manifest contains {len(packages)}")

    failures = 0
    print("CLASH OF LEGENDS — RESOURCE PACKAGE VERIFICATION")
    print(f"Project root: {root}")
    print(f"Manifest: {manifest_path}")
    print("-" * 72)

    for package in packages:
        filename = package["file_name"]
        # Manifest destinations use Godot user://; staged source files live
        # in the project's resources/ directory before packaging.
        candidate = root / "resources" / filename
        expected_size = int(package["size_bytes"])
        expected_hash = str(package["sha256"]).lower()

        if not candidate.is_file():
            failures += 1
            print(f"MISSING  {filename}")
            print(f"         expected bytes: {expected_size:,}")
            print(f"         checked: {candidate}")
            continue

        actual_size = candidate.stat().st_size
        actual_hash = sha256_file(candidate)
        size_ok = actual_size == expected_size
        hash_ok = actual_hash == expected_hash
        if size_ok and hash_ok:
            print(f"VERIFIED {filename} ({actual_size:,} bytes)")
        else:
            failures += 1
            print(f"MISMATCH {filename}")
            print(f"         size: expected {expected_size:,}, got {actual_size:,} "
                  f"({'OK' if size_ok else 'FAIL'})")
            print(f"         sha256 expected: {expected_hash}")
            print(f"         sha256 actual:   {actual_hash}")
            print(f"         hash: {'OK' if hash_ok else 'FAIL'}")

    print("-" * 72)
    print(f"Result: {len(packages) - failures}/{len(packages)} packages verified")
    if failures:
        print("STOP: do not package or report the game as asset-complete.")
        return 1
    print("All resource packages match the manifest.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
