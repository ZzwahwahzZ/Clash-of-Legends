#!/usr/bin/env python3
"""Probe the Mobile item-minicon translation table for mount and equipment icon references."""
import csv, json, hashlib, struct
from pathlib import Path

INDEX = Path("reports/resource-source-index.csv")
if not INDEX.is_file():
    raise SystemExit("Resource source index is missing")
rows = list(csv.DictReader(INDEX.open("r", encoding="utf-8-sig", newline="")))

def inner(row):
    return row.get("source_path", "").split("!")[-1].replace("\\", "/").lower()

def find_source(suffix):
    for row in rows:
        if inner(row).endswith(suffix.lower()):
            path = Path(row.get("staged_path", ""))
            if path.is_file():
                return path, row
    return None, None

def decode_tq(data, seed):
    state = seed & 0xFFFFFFFF
    key = []
    for _ in range(128):
        state = (state * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        key.append(((state >> 16) & 0x7FFF) & 0xFF)
    out = bytearray(len(data))
    for i, value in enumerate(data):
        shifted = value ^ key[i % 128]
        shift = i % 8
        out[i] = shifted if shift == 0 else ((shifted >> shift) | (shifted << (8 - shift))) & 0xFF
    return bytes(out)

def printable_ratio(data):
    return sum(1 for b in data if b in (9, 10, 13) or 32 <= b < 127) / max(1, len(data))

def parse_sections(text):
    sections = {}
    section = ""
    pair_count = 0
    for raw in text.splitlines():
        line = raw.strip().lstrip("\ufeff")
        if not line or line.startswith((";", "#", "//")):
            continue
        if line.startswith("[") and "]" in line:
            section = line[1:line.index("]")].strip()
            sections.setdefault(section, {})
        elif "=" in line:
            key, value = line.split("=", 1)
            sections.setdefault(section, {})[key.strip()] = value.strip()
            pair_count += 1
    return sections, pair_count

path, source = find_source("ini/itemminicon_trans.dat")
if path is None:
    raise SystemExit("itemminicon_trans.dat not found")
raw = path.read_bytes()
probes = []
best = None
for seed in (9527, 12345, 10000, 1000, 1, 0):
    decoded = decode_tq(raw, seed)
    ratio = printable_ratio(decoded)
    text = decoded.decode("utf-8", errors="replace")
    sections, pairs = parse_sections(text)
    score = ratio + min(len(sections), 3000) / 300000 + min(pairs, 30000) / 3000000
    probes.append({
        "seed": seed, "printable_ratio": round(ratio, 6),
        "section_count": len(sections), "pair_count": pairs,
        "text_sample": text[:1200],
    })
    if best is None or score > best[0]:
        best = (score, seed, decoded, sections, pairs)

_, best_seed, best_decoded, best_sections, best_pairs = best
icon_ids = set()
mounttype_path, mounttype_source = find_source("ini/mounttype.dat")
mount_items = {}
if mounttype_path:
    mt = decode_tq(mounttype_path.read_bytes(), 9527).decode("utf-8", errors="replace")
    mount_items, _ = parse_sections(mt)
    icon_ids = {str(props.get("IconId", "")).strip() for props in mount_items.values() if props.get("IconId")}
icon_matches = {}
decoded_text = best_decoded.decode("utf-8", errors="replace")
for icon_id in sorted(icon_ids):
    hits = []
    for section, values in best_sections.items():
        for key, value in values.items():
            if icon_id == key or icon_id == value:
                hits.append({"section": section, "key": key, "value": value})
    if hits:
        icon_matches[icon_id] = hits[:20]
literal_icon_occurrences = {icon_id: decoded_text.count(icon_id) for icon_id in sorted(icon_ids) if decoded_text.count(icon_id)}

pvr_rows = [r for r in rows if inner(r).endswith(".pvr") and "itemminicon" in inner(r)]
report = {
    "schema_version": "1.0.0",
    "source_file": str(path),
    "source_path": source.get("source_path"),
    "source_sha256": hashlib.sha256(raw).hexdigest(),
    "source_size_bytes": len(raw),
    "raw_hex_head_256": raw[:256].hex(),
    "raw_ascii_head_128": "".join(chr(b) if 32 <= b < 127 else "." for b in raw[:128]),
    "binary_u32x4_record_count_if_16_byte_aligned": len(raw) // 16 if len(raw) % 16 == 0 else None,
    "binary_u32x4_first_32_records_if_16_byte_aligned": [list(struct.unpack_from("<4I", raw, offset)) for offset in range(0, min(len(raw) - 15, 16 * 32), 16)] if len(raw) % 16 == 0 else [],
    "candidate_decodes": probes,
    "best_seed_by_text_structure_score": best_seed,
    "best_decode_printable_ratio": round(printable_ratio(best_decoded), 6),
    "best_decode_section_count": len(best_sections),
    "best_decode_pair_count": best_pairs,
    "mounttype_section_count": len(mount_items),
    "mount_icon_id_count": len(icon_ids),
    "mount_icon_ids_sample": sorted(icon_ids)[:100],
    "mount_icon_id_matches": icon_matches,
    "mount_icon_literal_occurrences": literal_icon_occurrences,
    "mount_icon_id_binary_word_offsets": {
        icon_id: [offset for offset in range(0, len(raw) - 3, 4) if struct.unpack_from("<I", raw, offset)[0] == int(icon_id)][:30]
        for icon_id in sorted(icon_ids)
        if any(struct.unpack_from("<I", raw, offset)[0] == int(icon_id) for offset in range(0, len(raw) - 3, 4))
    },
    "itemminicon_pvr_count": len(pvr_rows),
    "itemminicon_pvr_samples": [r.get("source_path") for r in pvr_rows[:100]],
    "status": "ICON_TRANSLATION_FORMAT_PROBED_REQUIRES_SPRITE_COORDINATE_AND_VISUAL_VALIDATION",
}
out = Path("reports/equipment-icon-translation-probe.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("EQUIPMENT_ICON_TRANSLATION_PROBE", json.dumps({
    "file_bytes": len(raw), "best_seed": best_seed,
    "printable_ratio": report["best_decode_printable_ratio"],
    "sections": len(best_sections), "pairs": best_pairs,
    "mount_icon_ids": len(icon_ids), "matched_icon_ids": len(icon_matches),
    "itemminicon_pvr_count": len(pvr_rows),
}, ensure_ascii=False))
