#!/usr/bin/env python3
"""Verify that all eleven manifest-declared PCKs are present in the APK staging folder."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

EXPECTED_COUNT = 11

def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def validate(bundle_dir: Path, manifest_path: Path) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = manifest.get("resource_packages", [])
    if manifest.get("package_id") != "com.zwahwahzz.clashoflegends":
        raise ValueError("Manifest package_id does not match the Android application")
    if manifest.get("release_tag") != "resource-packs-v4":
        raise ValueError("Unexpected PCK release tag")
    if len(entries) != EXPECTED_COUNT:
        raise ValueError(f"Expected exactly {EXPECTED_COUNT} PCK entries; found {len(entries)}")
    names: set[str] = set()
    total = 0
    verified = []
    for entry in entries:
        name = str(entry.get("file_name", ""))
        if not name or Path(name).name != name or not name.lower().endswith(".pck"):
            raise ValueError(f"Unsafe or invalid PCK filename: {name!r}")
        if name in names:
            raise ValueError(f"Duplicate PCK filename: {name}")
        names.add(name)
        path = bundle_dir / name
        if not path.is_file():
            raise FileNotFoundError(f"Required PCK is missing from APK staging: {path}")
        size = path.stat().st_size
        expected_size = int(entry.get("size_bytes", 0))
        if size != expected_size:
            raise ValueError(f"{name}: size mismatch {size} != {expected_size}")
        actual_hash = digest(path)
        expected_hash = str(entry.get("sha256", "")).lower()
        if actual_hash != expected_hash:
            raise ValueError(f"{name}: SHA-256 mismatch {actual_hash} != {expected_hash}")
        total += size
        verified.append({"file_name": name, "size_bytes": size, "sha256": actual_hash})
        print(f"OFFLINE PCK VERIFIED: {name} | {size} bytes | SHA-256 OK")
    actual_names = {p.name for p in bundle_dir.glob("*.pck")}
    if actual_names != names:
        raise ValueError(f"Unexpected PCK files in bundle directory: {sorted(actual_names ^ names)}")
    result = {"status": "PASS", "package_count": len(verified), "total_bytes": total, "packages": verified}
    print(f"OFFLINE BUNDLE READY: {len(verified)} PCKs, {total} bytes")
    return result

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", type=Path)
    parser.add_argument("--manifest", type=Path, default=Path("RESOURCE_MANIFEST"))
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = validate(args.bundle_dir, args.manifest)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\\n", encoding="utf-8")

if __name__ == "__main__":
    main()
