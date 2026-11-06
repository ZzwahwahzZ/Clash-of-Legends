#!/usr/bin/env python3
"""Extract individual resources from Conquer Mobile NetDragonDatPkg TPI/TPD pairs.

This is an independent parser based on the observed Mobile package layout:
TPI index (NetDragonDatPkg) + paired TPD payload file. It never modifies inputs.
"""
from __future__ import annotations
import argparse, hashlib, json, os, struct, zlib
from pathlib import Path, PurePosixPath

MAGIC = b"NetDragonDatPkg"
HEADER_SIZE = 0x30
MAX_ENTRIES = 0xFFFFFF
MAX_ENTRY_SIZE = 512 * 1024 * 1024

def safe_rel(name: str) -> Path:
    name = name.replace("\\", "/").strip("/")
    p = PurePosixPath(name)
    if not name or p.is_absolute() or any(part in ("", ".", "..") for part in p.parts):
        raise ValueError(f"unsafe TPI path: {name!r}")
    return Path(*p.parts)

def inflate_payload(data: bytes) -> bytes:
    errors = []
    for window in (zlib.MAX_WBITS, -zlib.MAX_WBITS):
        try:
            return zlib.decompress(data, window)
        except zlib.error as exc:
            errors.append(str(exc))
    raise ValueError("TPI DEFLATE decode failed: " + " | ".join(errors))

def parse_tpi(tpi: Path, tpd: Path) -> tuple[list[dict], list[dict]]:
    raw = tpi.read_bytes()
    if len(raw) < HEADER_SIZE or raw[:len(MAGIC)] != MAGIC:
        raise ValueError(f"invalid NetDragonDatPkg TPI header: {tpi}")
    count = struct.unpack_from("<I", raw, 0x24)[0]
    if count <= 0 or count > MAX_ENTRIES:
        raise ValueError(f"invalid TPI entry count: {count}")
    data = tpd.read_bytes()
    pos = HEADER_SIZE
    entries, errors = [], []
    for index in range(count):
        try:
            if pos >= len(raw):
                raise ValueError("index ended before declared entry count")
            path_len = raw[pos]
            pos += 1
            if path_len == 0 or pos + path_len + 22 > len(raw):
                raise ValueError("truncated path/index record")
            path = raw[pos:pos+path_len].decode("cp1252", "replace")
            pos += path_len + 2
            unpacked, packed, packed2, unpacked2, offset = struct.unpack_from("<IIIII", raw, pos)
            pos += 20
            if packed != packed2 or unpacked != unpacked2:
                raise ValueError("duplicate size fields disagree")
            if packed > MAX_ENTRY_SIZE or unpacked > MAX_ENTRY_SIZE:
                raise ValueError("entry exceeds safety size limit")
            if offset > len(data) or packed > len(data) - offset:
                raise ValueError("entry payload outside paired TPD bounds")
            payload = data[offset:offset+packed]
            if packed != unpacked:
                payload = inflate_payload(payload)
            if len(payload) != unpacked:
                raise ValueError(f"decoded size mismatch: expected {unpacked}, got {len(payload)}")
            entries.append({"index": index, "path": path, "offset": offset, "packed_size": packed,
                            "unpacked_size": unpacked, "sha256": hashlib.sha256(payload).hexdigest(),
                            "data": payload})
        except Exception as exc:
            errors.append({"index": index, "error": str(exc)})
            # A corrupt record may make subsequent boundaries unknowable.
            break
    return entries, errors

def run(root: Path, out: Path) -> dict:
    if not root.is_dir():
        raise SystemExit(f"source root does not exist: {root}")
    out.mkdir(parents=True, exist_ok=True)
    tpis = sorted(p for p in root.rglob("*.tpi") if p.is_file())
    extracted, errors, packages = 0, [], []
    for tpi in tpis:
        tpd = next((p for p in tpi.parent.iterdir()
                    if p.is_file() and p.name.lower() == (tpi.stem + ".tpd").lower()), None)
        if tpd is None:
            errors.append({"tpi": str(tpi), "error": "paired TPD file not found"})
            continue
        try:
            entries, entry_errors = parse_tpi(tpi, tpd)
            package_dir = out / tpi.relative_to(root).parent / tpi.stem
            package_dir.mkdir(parents=True, exist_ok=True)
            package_count = 0
            for entry in entries:
                try:
                    rel = safe_rel(entry["path"])
                    dst = package_dir / rel
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    dst.write_bytes(entry.pop("data"))
                    entry["output"] = str(dst)
                    package_count += 1
                except Exception as exc:
                    entry.pop("data", None)
                    entry_errors.append({"index": entry.get("index"), "path": entry.get("path"), "error": str(exc)})
            extracted += package_count
            packages.append({"tpi": str(tpi), "tpd": str(tpd), "entries_written": package_count,
                             "entry_errors": len(entry_errors), "entries": entries})
            errors.extend({"tpi": str(tpi), **e} for e in entry_errors)
        except Exception as exc:
            errors.append({"tpi": str(tpi), "error": str(exc)})
    report = {"schema_version": "1.0.0", "source_root": str(root), "tpi_count": len(tpis),
              "packages": packages, "extracted_count": extracted, "errors": errors}
    (out / "tpi-extraction-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = {"tpi_count": len(tpis), "extracted": extracted, "errors": len(errors), "report": str(out / "tpi-extraction-report.json")}
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return report

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source_root", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    run(args.source_root, args.out)

if __name__ == "__main__":
    main()
