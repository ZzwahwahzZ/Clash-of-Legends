#!/usr/bin/env python3
"""Safely inventory Android ELF shared libraries in extracted archives and APK containers.

Only .so members are copied to the private output directory; source archives remain untouched.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import struct
import zipfile
from pathlib import Path, PurePosixPath
from typing import BinaryIO

ARCHIVES = {".apk", ".apks", ".xapk", ".obb", ".zip"}
MAX_LIBRARY_BYTES = 256 * 1024 * 1024
MAX_NESTED_ARCHIVE_BYTES = 512 * 1024 * 1024
MAX_TOTAL_LIBRARY_BYTES = 1024 * 1024 * 1024
MAX_NESTING = 4


def elf_metadata(data: bytes) -> dict:
    if len(data) < 20 or data[:4] != b"\x7fELF":
        return {"is_elf": False, "elf_class": None, "machine": None, "architecture": "unknown"}
    elf_class = {1: "ELF32", 2: "ELF64"}.get(data[4], "unknown")
    endian = {1: "<", 2: ">"}.get(data[5])
    machine = struct.unpack_from(endian + "H", data, 18)[0] if endian else None
    architecture = {3: "x86", 40: "armeabi-v7a/ARM", 62: "x86_64", 183: "arm64-v8a/AArch64"}.get(machine, "unknown")
    return {"is_elf": True, "elf_class": elf_class, "machine": machine, "architecture": architecture}


def safe_member(name: str) -> bool:
    path = PurePosixPath(name.replace("\\", "/"))
    return not path.is_absolute() and ".." not in path.parts and bool(path.parts)


def inspect(root: Path, output: Path) -> dict:
    if not root.is_dir():
        raise SystemExit(f"extracted root does not exist: {root}")
    output.mkdir(parents=True, exist_ok=True)
    records: list[dict] = []
    seen_hashes: set[str] = set()
    total_copied = 0

    def record_library(data: bytes, source: str, member: str, abi_hint: str | None) -> None:
        nonlocal total_copied
        if len(data) > MAX_LIBRARY_BYTES:
            records.append({"source": source, "member": member, "status": "SKIPPED_SIZE_LIMIT", "size_bytes": len(data)})
            return
        digest = hashlib.sha256(data).hexdigest()
        if digest in seen_hashes:
            records.append({"source": source, "member": member, "status": "DUPLICATE_SHA256", "size_bytes": len(data), "sha256": digest})
            return
        if total_copied + len(data) > MAX_TOTAL_LIBRARY_BYTES:
            records.append({"source": source, "member": member, "status": "SKIPPED_TOTAL_LIMIT", "size_bytes": len(data), "sha256": digest})
            return
        seen_hashes.add(digest)
        meta = elf_metadata(data)
        suffix = Path(member).suffix or ".so"
        safe_name = Path(member).name.replace("/", "_").replace("\\", "_")
        destination = output / f"{Path(safe_name).stem}-{digest[:12]}{suffix}"
        destination.write_bytes(data)
        total_copied += len(data)
        records.append({
            "source": source, "member": member,
            "status": "EXTRACTED" if meta["is_elf"] else "EXTRACTED_NON_ELF_SO",
            "size_bytes": len(data), "sha256": digest, "abi_hint": abi_hint,
            "output": str(destination), **meta,
        })

    def scan_zip(stream: BinaryIO, source: str, depth: int) -> None:
        if depth > MAX_NESTING:
            return
        try:
            archive = zipfile.ZipFile(stream)
        except (zipfile.BadZipFile, OSError, ValueError):
            return
        with archive:
            for info in archive.infolist():
                if info.is_dir() or not safe_member(info.filename):
                    continue
                member_path = PurePosixPath(info.filename.replace("\\", "/"))
                suffix = member_path.suffix.lower()
                if suffix == ".so" and ("lib" in member_path.parts or member_path.name.startswith("lib")):
                    if info.file_size > MAX_LIBRARY_BYTES:
                        records.append({"source": source, "member": info.filename, "status": "SKIPPED_SIZE_LIMIT", "size_bytes": info.file_size})
                        continue
                    try:
                        data = archive.read(info)
                    except (RuntimeError, zipfile.BadZipFile, OSError):
                        records.append({"source": source, "member": info.filename, "status": "READ_ERROR", "size_bytes": info.file_size})
                        continue
                    abi = next((part for part in member_path.parts if part in {"arm64-v8a", "armeabi-v7a", "x86_64", "x86"}), None)
                    record_library(data, source, info.filename, abi)
                elif suffix in ARCHIVES and depth < MAX_NESTING and info.file_size <= MAX_NESTED_ARCHIVE_BYTES:
                    try:
                        nested = archive.read(info)
                    except (RuntimeError, zipfile.BadZipFile, OSError):
                        continue
                    scan_zip(io.BytesIO(nested), f"{source}!/{info.filename}", depth + 1)

    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        suffix = path.suffix.lower()
        if suffix == ".so":
            try:
                data = path.read_bytes()
            except OSError:
                continue
            abi = next((part for part in path.parts if part in {"arm64-v8a", "armeabi-v7a", "x86_64", "x86"}), None)
            record_library(data, str(path), path.name, abi)
        elif suffix in ARCHIVES:
            try:
                with path.open("rb") as stream:
                    scan_zip(stream, str(path), 0)
            except OSError:
                continue

    extracted = [row for row in records if row.get("status") in {"EXTRACTED", "EXTRACTED_NON_ELF_SO"}]
    report = {
        "schema_version": "1.0.0", "source_root": str(root),
        "status": "FOUND" if extracted else "NOT_FOUND",
        "library_records": len(records), "unique_libraries_extracted": len(extracted),
        "total_extracted_bytes": total_copied,
        "architecture_counts": {
            arch: sum(1 for row in extracted if row.get("architecture") == arch)
            for arch in sorted({row.get("architecture", "unknown") for row in extracted})
        },
        "records": records,
        "note": "No APK is downloaded. Only native .so members already present in the selected source archive are inspected and copied to this private output directory.",
    }
    (output / "native-library-inventory.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with (output / "native-library-inventory.csv").open("w", encoding="utf-8", newline="") as stream:
        fields = ["source", "member", "status", "size_bytes", "sha256", "abi_hint", "architecture", "elf_class", "machine", "output"]
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)
    summary = {key: report[key] for key in ("status", "library_records", "unique_libraries_extracted", "total_extracted_bytes", "architecture_counts")}
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    inspect(args.root, args.out)


if __name__ == "__main__":
    main()
