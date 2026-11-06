#!/usr/bin/env python3
"""Identify FairyGUI binary .fui packages without assuming every .fui is FairyGUI V7."""
from __future__ import annotations
import argparse, csv, hashlib, json, struct
from pathlib import Path


def inspect(root: Path, output: Path) -> dict:
    if not root.is_dir():
        raise SystemExit(f"extracted root does not exist: {root}")
    output.mkdir(parents=True, exist_ok=True)
    rows = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() != ".fui":
            continue
        try:
            with path.open("rb") as stream:
                head = stream.read(64)
            size = path.stat().st_size
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError as exc:
            rows.append({"path": str(path), "status": "READ_ERROR", "error": str(exc)})
            continue
        is_magic = head[:4] == b"FGUI"
        version = struct.unpack_from("<I", head, 4)[0] if is_magic and len(head) >= 8 else None
        compressed = bool(head[8]) if is_magic and len(head) >= 9 else None
        rows.append({
            "path": str(path), "size_bytes": size, "sha256": digest,
            "magic_ascii": head[:4].decode("ascii", "replace"), "magic_hex": head[:4].hex(),
            "is_fairygui_binary": is_magic, "version": version, "compressed": compressed,
            "status": "V7_CANDIDATE" if is_magic and version == 7 else ("OTHER_FGUI_VERSION" if is_magic else "UNKNOWN_FUI_FORMAT"),
            "header_hex": head[:32].hex(),
        })
    candidates = [row for row in rows if row["status"] == "V7_CANDIDATE"]
    report = {
        "schema_version": "1.0.0", "source_root": str(root), "file_count": len(rows),
        "fairygui_v7_candidates": len(candidates),
        "other_fairygui_versions": sum(row["status"] == "OTHER_FGUI_VERSION" for row in rows),
        "unknown_fui_formats": sum(row["status"] == "UNKNOWN_FUI_FORMAT" for row in rows),
        "records": rows,
        "note": "V7_CANDIDATE means only that the FGUI magic and version header match. Full parsing and component validation are performed separately by OpenFairyGUI.",
    }
    (output / "fui-header-inventory.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with (output / "fui-header-inventory.csv").open("w", encoding="utf-8", newline="") as stream:
        fields = ["path", "size_bytes", "sha256", "magic_ascii", "magic_hex", "is_fairygui_binary", "version", "compressed", "status", "header_hex"]
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps({key: report[key] for key in ("file_count", "fairygui_v7_candidates", "other_fairygui_versions", "unknown_fui_formats")}, ensure_ascii=False, indent=2))
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    inspect(args.root, args.out)


if __name__ == "__main__":
    main()
