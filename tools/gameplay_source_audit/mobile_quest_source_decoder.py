#!/usr/bin/env python3
"""Version-pinned quest resource decoder/auditor for Conquer Mobile 1.1.2.3.

TQ decryptions are candidates only; the Android reader/schema must independently
confirm the exact format before any data is admitted into runtime.
"""
from __future__ import annotations
import argparse, hashlib, json, re, tempfile, zipfile
from pathlib import Path

VERSION = "ConquerOnline-1.1.2.3"
ROOT = "assets/ConquerRes/"
SEEDS = (9527, 1234)

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def key_for(seed: int) -> bytes:
    # Match the documented Microsoft rand() state width used by TQ File Cipher.
    state = seed & 0xFFFFFFFF
    key = bytearray()
    for _ in range(128):
        state = (state * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        key.append(((state >> 16) & 0x7fff) & 0xff)
    return bytes(key)

def decrypt_tq(data: bytes, seed: int) -> bytes:
    key = key_for(seed)
    out = bytearray(len(data))
    for i, value in enumerate(data):
        v = value ^ key[i & 127]
        shift = i & 7
        out[i] = v if shift == 0 else ((v >> shift) | (v << (8-shift))) & 255
    return bytes(out)

def signals(data: bytes) -> dict:
    sample = data[:min(len(data), 256 * 1024)]
    if not sample:
        return {"printable_ratio": 0.0, "lua_signature": False, "ini_signature": False}
    # Count ASCII text bytes only. High bytes are not automatically printable:
    # encrypted/compressed data can contain many 0xC0-0xFF bytes by chance.
    printable = sum(x in (9, 10, 13) or 32 <= x <= 126 for x in sample) / len(sample)
    text = sample.decode("ascii", errors="ignore")
    return {
        "printable_ratio": round(printable, 4),
        "lua_signature": bool(re.search(r"(?m)^\s*(local\s+\w+|return\s+\w+)", text) or "ret.data" in text or "MainTask" in text),
        "ini_signature": bool(re.search(r"(?m)^\s*\[[^]\r\n]+\]", text) and re.search(r"(?m)^\s*[^;#\r\n][^=\r\n]*=", text)),
    }

def classify(data: bytes) -> str:
    if data.startswith(b"\x1f\x8b"):
        return "GZIP"
    if data.startswith((b"PK\x03\x04", b"PK\x05\x06")):
        return "ZIP"
    if data.startswith(b"\x1bLua"):
        return "LUA_BYTECODE"
    s = signals(data)
    if s["printable_ratio"] >= .88 and (s["lua_signature"] or s["ini_signature"]):
        return "PLAINTEXT_LUA_OR_INI_CANDIDATE"
    if s["printable_ratio"] >= .92:
        return "PLAINTEXT_TEXT_CANDIDATE"
    return "BINARY_OR_ENCRYPTED_UNCLASSIFIED"

def is_target(path: str) -> bool:
    p = path.lower()
    base = p.rsplit("/", 1)[-1]
    return (
        base in {"questinfo.dat", "taskitem_info.dat", "mission.dat", "process_task.dat",
                 "task_reward_type.dat", "questinfo.ini", "questinfopassionserver.ini", "activitytask.ini"}
        or ("/client_realm_task/" in p and re.fullmatch(r"juqing\d+\.dat", base))
        or ("/script/" in p and re.fullmatch(r"clienttask\d+\.dat", base))
    )

def extract_candidate_records(data: bytes, role: str) -> dict:
    text = data.decode("latin-1")
    if role == "questinfo":
        ids = [int(x) for x in re.findall(r'\["TaskID"\]\s*=\s*(\d+)', text)]
        fields = {}
        for name in ("Goal", "GoalPos", "MapID", "MapX", "MapY", "NpcID", "ReachMapID",
                     "ReachMapX", "ReachMapY", "ReachNpcID", "IntentionCount"):
            vals = re.findall(r'\["' + name + r'"\]\s*=\s*(-?\d+)', text)
            if vals:
                fields[name] = [int(x) for x in vals]
        return {"task_ids": ids, "task_id_count": len(ids), "numeric_field_occurrences": fields}
    if role == "taskitem_info":
        ids = [int(x) for x in re.findall(r"itemtype\d+\s*=\s*(\d+)", text)]
        return {"item_type_ids": ids, "item_type_count": len(ids),
                "item_cd_values": [int(x) for x in re.findall(r"itemcd\s*=\s*(\d+)", text)]}
    return {}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--decoded-dir", type=Path, default=Path("build/mobile_quest_candidates"))
    args = parser.parse_args()
    if not args.archive.is_file():
        raise SystemExit(f"archive not found: {args.archive}")
    records, apk_names, apk_provenance = [], [], []
    with zipfile.ZipFile(args.archive) as outer, tempfile.TemporaryDirectory(prefix="quest-apk-") as temp:
        apk_members = [n for n in outer.namelist() if VERSION in n and n.lower().endswith(".apk")]
        if not apk_members:
            raise SystemExit("Exact-version Android APK not found in source archive")
        for apk_member in apk_members:
            apk_path = Path(temp) / f"{len(apk_names)}.apk"
            apk_hasher = hashlib.sha256()
            apk_size = 0
            with outer.open(apk_member) as src, apk_path.open("wb") as dst:
                while True:
                    block = src.read(1024 * 1024)
                    if not block:
                        break
                    dst.write(block)
                    apk_hasher.update(block)
                    apk_size += len(block)
            apk_names.append(apk_member)
            apk_provenance.append({
                "archive_member": apk_member,
                "size_bytes": apk_size,
                "sha256": apk_hasher.hexdigest(),
            })
            with zipfile.ZipFile(apk_path) as apk:
                for member in apk.namelist():
                    if not member.startswith(ROOT) or not is_target(member):
                        continue
                    raw = apk.read(member)
                    relative = member[len(ROOT):]
                    row = {"apk_member": apk_member + "!" + member, "relative_path": relative,
                           "size_bytes": len(raw), "sha256": sha(raw),
                           "raw_classification": classify(raw), "raw_signals": signals(raw)}
                    role = "questinfo" if relative.lower().endswith("/questinfo.dat") or relative.lower() == "ini/luacfg/questinfo.dat" else (
                        "taskitem_info" if relative.lower().endswith("taskitem_info.dat") else "other")
                    if role in ("questinfo", "taskitem_info"):
                        row["cipher_candidates"] = []
                        for seed in SEEDS:
                            candidate = decrypt_tq(raw, seed)
                            sig = signals(candidate)
                            plausible = sig["lua_signature"] and sig["printable_ratio"] >= .85
                            item = {"cipher": "TQ_FILE_CIPHER_CANDIDATE", "seed": seed,
                                    "signals": sig, "structure_candidate": plausible}
                            if plausible:
                                item.update(extract_candidate_records(candidate, role))
                                locale = "ar" if "/ini_ar/" in "/" + relative.lower() else (
                                    "sp" if "/ini_sp/" in "/" + relative.lower() else "default")
                                output = args.decoded_dir / role / locale / (Path(relative).stem + f"_seed_{seed}.lua")
                                output.parent.mkdir(parents=True, exist_ok=True)
                                output.write_bytes(candidate)
                                item["candidate_output"] = str(output)
                                item["candidate_sha256"] = sha(candidate)
                            row["cipher_candidates"].append(item)
                    records.append(row)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    report = {"schema_version": "1.1.0", "source_client": VERSION, "apk_members": apk_names,
              "apk_member_provenance": apk_provenance,
              "files_found": len(records), "records": records,
              "acceptance_policy": "All TQ decryptions remain candidates until independently matched to the exact Android 1.1.2.3 reader/schema. No guessed PC format, field, ID join or candidate is approved for runtime."}
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"source_client": VERSION, "files_found": len(records),
        "by_raw_classification": {k: sum(x["raw_classification"] == k for x in records) for k in sorted({x["raw_classification"] for x in records})},
        "candidate_files": sum(len(x.get("cipher_candidates", [])) for x in records)}, ensure_ascii=False))

if __name__ == "__main__":
    main()
