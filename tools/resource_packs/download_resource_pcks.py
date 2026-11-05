#!/usr/bin/env python3
"""Download and verify the user's approved resource-packs-v4 baseline."""
from __future__ import annotations
import hashlib
import json
import os
import subprocess
from pathlib import Path
from urllib.request import urlopen

ROOT = Path.cwd()
MANIFEST = ROOT / "RESOURCE_MANIFEST"
OUTPUT = ROOT / "build" / "source_packs"
REPORTS = ROOT / "reports"
INDEX_NAME = "resource-source-index.csv"

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "curl", "--fail", "--location", "--retry", "10",
        "--retry-all-errors", "--retry-delay", "5",
        "--connect-timeout", "30", "--max-time", "0",
        "--continue-at", "-", url, "-o", str(destination),
    ]
    result = subprocess.run(command, check=False)
    if result.returncode != 0:
        # gh uses the GitHub Releases API and is a second retrieval route.
        token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
        if not token:
            raise RuntimeError(f"Download failed ({result.returncode}) and no GitHub token is available: {url}")
        repo = "ZzwahwahzZ/Clash-of-Legends"
        name = destination.name
        subprocess.run(
            ["gh", "release", "download", "resource-packs-v4", "--repo", repo, "--pattern", name, "--dir", str(destination.parent), "--clobber"],
            check=True,
            env={**os.environ, "GH_TOKEN": token},
        )
    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError(f"Downloaded file is missing or empty: {destination}")

def main() -> None:
    if not MANIFEST.is_file():
        raise SystemExit("RESOURCE_MANIFEST is missing.")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("release_tag") != "resource-packs-v4":
        raise SystemExit("RESOURCE_MANIFEST does not point to resource-packs-v4.")
    if manifest.get("distribution_allowed") is not True:
        raise SystemExit("The user-approved resource distribution ledger does not permit this baseline.")
    packages = manifest.get("resource_packages", [])
    if not packages:
        raise SystemExit("RESOURCE_MANIFEST contains no resource packages.")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)
    verified = []
    for package in packages:
        name = package["file_name"]
        destination = OUTPUT / name
        download(package["download_url"], destination)
        actual_size = destination.stat().st_size
        actual_hash = sha256(destination)
        expected_size = int(package["size_bytes"])
        expected_hash = str(package["sha256"]).lower()
        if actual_size != expected_size or actual_hash != expected_hash:
            raise RuntimeError(
                f"Integrity failure for {name}: size {actual_size}/{expected_size}, sha256 {actual_hash}/{expected_hash}"
            )
        verified.append({"file_name": name, "size_bytes": actual_size, "sha256": actual_hash})
        print(f"VERIFIED {name}: {actual_size} bytes sha256:{actual_hash}")

    base = "https://github.com/ZzwahwahzZ/Clash-of-Legends/releases/download/resource-packs-v4"
    index_path = ROOT / INDEX_NAME
    download(f"{base}/{INDEX_NAME}", index_path)
    index_hash = sha256(index_path)
    if index_path.stat().st_size < 1000:
        raise RuntimeError("resource-source-index.csv is unexpectedly small.")
    with index_path.open("r", encoding="utf-8-sig") as stream:
        header = stream.readline().strip().split(",")
    required = {"category", "staged_path", "source_path", "size_bytes", "sha256"}
    if not required.issubset(set(header)):
        raise RuntimeError(f"resource-source-index.csv is missing required columns: {sorted(required - set(header))}")
    report = {
        "baseline_release": "resource-packs-v4",
        "distribution_allowed": True,
        "distribution_policy": manifest.get("distribution_policy", ""),
        "verified_packages": verified,
        "source_index": {"file_name": INDEX_NAME, "size_bytes": index_path.stat().st_size, "sha256": index_hash},
    }
    (REPORTS / "source-pck-download-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"VERIFIED {len(verified)} PCK packages and source index sha256:{index_hash}")

if __name__ == "__main__":
    main()
