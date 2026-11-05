#!/usr/bin/env python3
"""Extract audio payloads embedded in staged resource PCK 7z archives.

Only audio file members are extracted. Every output is indexed with the exact
outer archive path, inner member path, byte size and SHA-256. Unsafe paths and
archive errors fail closed.
"""
from __future__ import annotations

import csv
import hashlib
import json
import shutil
import tempfile
from pathlib import Path, PurePosixPath

import py7zr

ROOT = Path.cwd()
AUDIO_ROOT = ROOT / "resource_stage" / "audio"
INDEX = ROOT / "reports" / "resource-source-index.csv"
REPORT = ROOT / "reports" / "nested-audio-extraction.json"
AUDIO_EXTENSIONS = {".ogg", ".wav", ".mp3", ".flac", ".mid", ".midi", ".opus", ".aac", ".m4a"}
FIELDS = ["category", "source_archive", "source_path", "staged_path", "size_bytes", "sha256"]


def safe_member(name: str) -> str | None:
    normalized = name.replace("\\", "/")
    path = PurePosixPath(normalized)
    if path.is_absolute() or (path.parts and path.parts[0].endswith(":")) or any(part in ("", ".", "..") for part in path.parts):
        return None
    return path.as_posix()


def main() -> None:
    if not AUDIO_ROOT.is_dir() or not INDEX.is_file():
        raise SystemExit("Audio staging directory or verified resource source index is missing.")
    rows = list(csv.DictReader(INDEX.open("r", encoding="utf-8-sig", newline="")))
    # The index also contains 904 source-only paths absent from the published
    # baseline PCKs. Only files physically present in staging count as duplicates.
    seen_hashes: set[str] = set()
    for row in rows:
        staged = str(row.get("staged_path", "")).replace("\\", "/")
        staged_path = ROOT / Path(staged)
        if staged_path.is_file():
            seen_hashes.add(str(row.get("sha256", "")).lower())
    archives = sorted(path for path in AUDIO_ROOT.rglob("*") if path.is_file() and path.suffix.lower() == ".7z" and "nested_7z" not in path.parts)
    report = {
        "archives_found": len(archives),
        "archives_with_audio": 0,
        "audio_members_found": 0,
        "audio_members_extracted": 0,
        "duplicate_members": 0,
        "bytes_extracted": 0,
        "errors": [],
        "archive_results": [],
    }
    new_rows: list[dict] = []
    for archive_path in archives:
        relative_archive = archive_path.relative_to(ROOT).as_posix()
        archive_result = {"archive": relative_archive, "audio_members": 0, "extracted": 0, "bytes": 0, "error": ""}
        try:
            with py7zr.SevenZipFile(archive_path, mode="r") as archive:
                targets = []
                for raw_name in archive.getnames():
                    member = safe_member(raw_name)
                    if member is None:
                        continue
                    if Path(member).suffix.lower() in AUDIO_EXTENSIONS:
                        targets.append(raw_name)
                archive_result["audio_members"] = len(targets)
                report["audio_members_found"] += len(targets)
                if not targets:
                    report["archive_results"].append(archive_result)
                    continue
                report["archives_with_audio"] += 1
                with tempfile.TemporaryDirectory(prefix="clash-audio-7z-") as temp_dir:
                    archive.extract(path=temp_dir, targets=targets)
                    extracted_root = Path(temp_dir)
                    for extracted_path in sorted(extracted_root.rglob("*")):
                        if not extracted_path.is_file():
                            continue
                        inner = extracted_path.relative_to(extracted_root).as_posix()
                        if Path(inner).suffix.lower() not in AUDIO_EXTENSIONS:
                            continue
                        data_hash = hashlib.sha256()
                        size = 0
                        with extracted_path.open("rb") as stream:
                            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                                data_hash.update(chunk)
                                size += len(chunk)
                        digest = data_hash.hexdigest()
                        if size <= 0:
                            continue
                        if digest in seen_hashes:
                            report["duplicate_members"] += 1
                            continue
                        archive_parent = archive_path.relative_to(AUDIO_ROOT).parent
                        output_rel = Path("resource_stage/audio/nested_7z") / archive_parent / archive_path.stem / Path(inner)
                        output_path = ROOT / output_rel
                        output_path.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(extracted_path, output_path)
                        new_rows.append({
                            "category": "audio",
                            "source_archive": "resource-packs-v4",
                            "source_path": relative_archive + "!" + inner,
                            "staged_path": output_rel.as_posix(),
                            "size_bytes": size,
                            "sha256": digest,
                        })
                        seen_hashes.add(digest)
                        report["audio_members_extracted"] += 1
                        report["bytes_extracted"] += size
                        archive_result["extracted"] += 1
                        archive_result["bytes"] += size
        except Exception as exc:
            archive_result["error"] = str(exc)[:500]
            report["errors"].append({"archive": relative_archive, "error": archive_result["error"]})
        report["archive_results"].append(archive_result)
    if new_rows:
        with INDEX.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS)
            writer.writeheader()
            writer.writerows(rows)
            writer.writerows(new_rows)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("NESTED AUDIO EXTRACTION: " + json.dumps({k: report[k] for k in (
        "archives_found", "archives_with_audio", "audio_members_found",
        "audio_members_extracted", "duplicate_members", "bytes_extracted"
    )}, ensure_ascii=False))
    if report["errors"]:
        raise SystemExit(f"Nested audio extraction failed for {len(report['errors'])} archive(s).")


if __name__ == "__main__":
    main()
