#!/usr/bin/env python3
"""Inventory nested Android APKs and surface resource/decryption clues without modifying assets.

The report contains metadata and matching strings only; extracted APKs and libraries stay
inside the caller's private working directory and are not committed or uploaded.
"""
from __future__ import annotations
import argparse, hashlib, json, re, struct, zipfile
from pathlib import Path, PurePosixPath

ARCHIVE_SUFFIXES = {".apk", ".apks", ".xapk", ".zip", ".obb"}
KEYWORDS = re.compile(
    rb"(?i)(assetmanager|openfd|openasset|loadlibrary|jni_onload|"
    rb"cipher|getinstance|secretkey|ivparameter|messagedigest|"
    rb"base64|inflate|deflate|gzip|zlib|lz4|zstd|snappy|"
    rb"xxtea|tea|aes|des|rsa|xor|decrypt|encrypt|decode|"
    rb"tpi|tpd|c3|mjp|pvr|resource|resmgr|filemanager|"
    rb"readasset|loadresource|unpack|uncompress|skeleton|motion)"
)
PRINTABLE = re.compile(rb"[ -~]{5,}")

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def safe_name(name: str) -> bool:
    p = PurePosixPath(name.replace("\\", "/"))
    return not p.is_absolute() and ".." not in p.parts

def scan_strings(data: bytes, limit: int = 500) -> list[str]:
    found, seen = [], set()
    for match in PRINTABLE.finditer(data):
        raw = match.group(0)
        if KEYWORDS.search(raw):
            s = raw[:300].decode("ascii", "replace")
            if s not in seen:
                seen.add(s); found.append(s)
                if len(found) >= limit: break
    return found

def dex_strings(data: bytes) -> list[str]:
    # DEX string_data_item uses ULEB128 UTF-16 length then modified UTF-8 bytes.
    # A printable-byte scan is deliberately conservative; JADX output provides richer xrefs.
    return scan_strings(data, 1000)

def elf_info(data: bytes) -> dict:
    if len(data) < 20 or data[:4] != b"\x7fELF":
        return {"elf": False}
    endian = {1:"<", 2:">"}.get(data[5])
    machine = struct.unpack_from(endian+"H", data, 18)[0] if endian else None
    return {"elf": True, "class": {1:32,2:64}.get(data[4]), "machine": machine,
            "arch": {183:"AArch64",40:"ARM",62:"x86_64",3:"x86"}.get(machine,"unknown")}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", type=Path, help="original source ZIP or extracted directory")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    extracted = args.out / "private_apk_extract"
    extracted.mkdir(exist_ok=True)
    apks, libs, dexes, errors = [], [], [], []

    def inspect_apk(blob: bytes, label: str):
        digest = sha(blob)
        target = extracted / f"{Path(label).stem}-{digest[:12]}.apk"
        target.write_bytes(blob)
        rec = {"source": label, "sha256": digest, "size": len(blob), "path": str(target)}
        try:
            with zipfile.ZipFile(target) as z:
                names = [n for n in z.namelist() if safe_name(n)]
                rec["dex_files"] = [n for n in names if re.fullmatch(r"classes(?:[0-9]+)?\.dex", PurePosixPath(n).name)]
                rec["native_libraries"] = [n for n in names if PurePosixPath(n).suffix.lower()==".so"]
                rec["resource_containers"] = [n for n in names if PurePosixPath(n).suffix.lower() in {".tpi",".tpd",".wdb",".c3",".mjp",".pvr"}]
                rec["asset_roots"] = sorted({"/".join(PurePosixPath(n).parts[:2]) for n in names if n.startswith("assets/")})[:100]
                for name in rec["dex_files"]:
                    data=z.read(name)
                    dexes.append({"apk":label,"member":name,"size":len(data),"sha256":sha(data),"clue_strings":dex_strings(data)})
                for name in rec["native_libraries"]:
                    data=z.read(name)
                    libs.append({"apk":label,"member":name,"size":len(data),"sha256":sha(data),**elf_info(data),"clue_strings":scan_strings(data,800)})
            apks.append(rec)
        except Exception as exc:
            errors.append({"source":label,"error":str(exc)})

    if args.source.is_dir():
        for p in sorted(args.source.rglob("*.apk")):
            inspect_apk(p.read_bytes(), str(p.relative_to(args.source)))
    else:
        try:
            with zipfile.ZipFile(args.source) as z:
                for info in z.infolist():
                    if not info.is_dir() and safe_name(info.filename) and PurePosixPath(info.filename).suffix.lower()==".apk":
                        inspect_apk(z.read(info), info.filename)
        except Exception as exc:
            raise SystemExit(f"Cannot read source archive: {exc}")

    report={"schema_version":"1.0.0","source":str(args.source),"apk_count":len(apks),
            "dex_count":len(dexes),"native_library_count":len(libs),
            "architectures":{a:sum(1 for x in libs if x.get("arch")==a) for a in sorted({x.get("arch","unknown") for x in libs})},
            "apks":apks,"dex_analysis":dexes,"native_analysis":libs,"errors":errors,
            "limits":"Printable string clues are leads only, not proof of encryption or an identified cipher. Validate call paths in JADX/Ghidra before implementing a decoder."}
    (args.out/"mobile-apk-static-analysis.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    summary={k:report[k] for k in ("apk_count","dex_count","native_library_count","architectures","errors")}
    print(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=="__main__": main()
