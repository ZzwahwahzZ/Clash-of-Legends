#!/usr/bin/env python3
"""Audit the TQ C3 WDB container and index its DBC tables.

The WDB block transform is independently implemented from the public BDMG
format descriptions. The fixed lookup table is a format constant observed in
public C3 WDB tooling; no third-party implementation code is copied here.
This tool emits metadata only and never publishes/extracts original DBC blobs.
"""
from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path

MASK = 0xFFFFFFFF
WDB_ENTRY_SIZE = 84
KEY_TABLE = (
    0x193aa698, 0x5496f7d5, 0x4208931b, 0x7a4106ec,
    0x83e86840, 0xf49b6f8c, 0xba3d9a51, 0x55f54ddd,
    0x2de51372, 0x9afb571b, 0x3ab35406, 0xad64ff1f,
    0xc77764fe, 0x7f864466, 0x416d9cd4, 0xa2489278,
    0xe30b86e4, 0x0b5231b6, 0xba67aed6, 0xe5ab2467,
    0x60028b90, 0x1d9e20c6, 0x2a7c692a, 0x6b691cdb,
    0x9e51f817, 0x9b763dec, 0x3d29323f, 0xcfe12b68,
    0x754b459b, 0xa2238047, 0xd9c55514, 0x6bdcffc1,
    0x693e6340, 0x82383fe7, 0x1916ea5f, 0xec7bcd59,
    0x72de165a, 0xe79a1617, 0x8ec86234, 0xa8f0d284,
    0x20c90226, 0x7bf98884, 0x28a58331, 0x3ec3fa6e,
    0x4ce0895b, 0xc353b4d0, 0x33ef064f, 0x21e5e210,
    0xc8bb589d, 0xe85dcab2, 0xac65829f, 0xa7bf92d0,
    0x05a6174d, 0x25a50c2e, 0xe5c78777, 0x3d75021f,
    0x4baa9c98, 0x23bdc884, 0x9653bbd7, 0xbadce7f5,
    0xc283a484, 0xc040df2e, 0x9370a841, 0x2f316022,
    0x36eed231, 0xac2cbc0c, 0x13c0a49b, 0xcdd12997,
    0x07fe91b2, 0xcd7eabcd, 0x2c01271d, 0x18432df8,
    0x599c6bc7, 0x75e93d5a, 0xb67a6ee2, 0x8e738e16,
    0xff9073fd, 0xaf77026a, 0xf86ea2fc, 0x91509ea3,
    0x33a78dc6, 0x4f79234a, 0x3a7535bc, 0x3539fcb1,
    0x3103ee52, 0x4f6f1e69, 0x6bb3ebbc, 0x4cb77555,
    0x8dd1e999, 0x2ade439d, 0x11521fae, 0xb94d2545,
    0x8dde9abd, 0x1909393f, 0xb792a23d, 0x749c455b,
    0xb5b60f2c, 0x380459ce, 0x0dad5820, 0xb130845b,
    0x291cbd52, 0xde9a5bb7, 0x51def961, 0x515b6408,
    0xca6e823e, 0x382e6e74, 0xeebe3d71, 0x4c8f0c6a,
    0xe676dcea, 0x14e1dc7c, 0x6f7fc634, 0xcf85a943,
    0xd39ea96e, 0x136e7c93, 0x7164b304, 0xf32f1333,
    0x35c34034, 0xde39d721, 0x91a87439, 0xc410111f,
    0x29f17aac, 0x1316a6ff, 0x12f194ee, 0x420b9499,
    0xf72db0dc, 0x690b9f93, 0x17d14bb2, 0x8f931ab8,
    0x217500bc, 0x875413f8, 0x98b2e43d, 0xc51f9571,
    0x54cebdca, 0x0719cc79, 0xf3c7080d, 0xe4286771,
    0xa3eab3cd, 0x4a6b00e0, 0x11cf0759, 0x7e897379,
    0x5b32876c, 0x5e8cd4f6, 0x0cedfa64, 0x919ac2c7,
    0xb214f3b3, 0x0e89c38c, 0xf0c43a39, 0xeae10522,
    0x835bce06, 0x9eec43c2, 0xea26a9d6, 0x69531821,
    0x6725b24a, 0xda81b0e2, 0xd5b4ae33, 0x080f99fb,
    0x15a83daf, 0x29dfc720, 0x91e1900f, 0x28163d58,
    0x83d107a2, 0x4eac149a, 0x9f71da18, 0x61d5c4fa,
    0xe3ab2a5f, 0xc7b0d63f, 0xb3cc752a, 0x61ebcfb6,
    0x26ffb52a, 0xed789e3f, 0xaa3bc958, 0x455a8788,
    0xc9c082a9, 0x0a1bef0e, 0xc29a5a7e, 0x150d4735,
    0x943809e0, 0x69215510, 0xef0b0da9, 0x3b4e9fb3,
    0xd8b5d04c, 0xc7a023a8, 0xb0d50288, 0x64821375,
    0xc260e8cf, 0x8496bd2c, 0xff4f5435, 0x0fb5560c,
    0x7cd74a52, 0x93589c80, 0x88975c47, 0x83bda89d,
    0x8bcc4296, 0x01b82c21, 0xfd821dbf, 0x26520b47,
    0x04983e19, 0xd3e1ca27, 0x782c580f, 0x326ff573,
    0xc157bcc7, 0x4f5e6b84, 0x44ebfbfb, 0xda26d9d8,
    0x6cd9d08e, 0x1719f1d8, 0x715c0487, 0x2c2d3c92,
    0x53faaba9, 0xbc836146, 0x510c92d6, 0xe089f82a,
    0x4680171f, 0x369f00de, 0x70ec2331, 0x0e253d55,
    0xdafb9717, 0xe5dd922d, 0x95915d21, 0xa0202f96,
    0xa161cc47, 0xeacfa6f1, 0xed5e9189, 0xdab87684,
    0xa4b76d4a, 0xfa704897, 0x631f10ba, 0xd39da8f9,
    0x5db4c0e4, 0x16fde42a, 0x2dff7580, 0xb56fec7e,
    0xc3ffb370, 0x8e6f36bc, 0x6097d459, 0x514d5d36,
    0xa5a737e2, 0x3977b9b3, 0xfd31a0ca, 0x903368db,
    0xe8370d61, 0x98109520, 0xade23cac, 0x99f82e04,
    0x41de7ea3, 0x84a1c295, 0x09191be0, 0x30930d02,
    0x1c9fa44a, 0xc406b6d7, 0xeedca152, 0x6149809c,
    0xb0099ef4, 0xc5f653a5, 0x4c10790d, 0x7303286c
)

BIG_TABLES = {"3dmotion", "armetmotion", "armormotion", "capemotion", "headmotion",
              "miscmotion", "mountmotion", "weaponmotion", "pelvismotion", "spiritmotion"}
# 3DTexture is tested as the same 32-bit ID + string-offset RSDB layout
# used by 3DObj/3DEffectObj; CI bounds-checks every record before accepting it.
SMALL_TABLES = {"3dobj", "3deffectobj", "3dtexture"}


def decrypt_entry_block(ciphertext: bytes) -> bytes:
    if len(ciphertext) != WDB_ENTRY_SIZE or len(ciphertext) % 4:
        raise ValueError("WDB encrypted table block must be exactly 84 bytes")
    out = bytearray(ciphertext)
    a, b = 0xEFFEAABB, 0xEEEEEEEE
    for offset in range(0, len(out), 4):
        word = struct.unpack_from("<I", out, offset)[0]
        b = (b + KEY_TABLE[a & 0xFF]) & MASK
        plain = ((b + a) & MASK) ^ word
        struct.pack_into("<I", out, offset, plain)
        a = ((a >> 11) | ((((~a) & MASK) << 21) + 0x11111111)) & MASK
        b = (b + plain + ((b << 5) & MASK) + 3) & MASK
    return bytes(out)


def encrypt_entry_block(plaintext: bytes) -> bytes:
    if len(plaintext) != WDB_ENTRY_SIZE or len(plaintext) % 4:
        raise ValueError("WDB plaintext table block must be exactly 84 bytes")
    out = bytearray(plaintext)
    a, b = 0xEFFEAABB, 0xEEEEEEEE
    for offset in range(0, len(out), 4):
        plain = struct.unpack_from("<I", out, offset)[0]
        b = (b + KEY_TABLE[a & 0xFF]) & MASK
        cipher = ((b + a) & MASK) ^ plain
        struct.pack_into("<I", out, offset, cipher)
        a = ((a >> 11) | ((((~a) & MASK) << 21) + 0x11111111)) & MASK
        b = (b + plain + ((b << 5) & MASK) + 3) & MASK
    return bytes(out)


def read_cstring(data: bytes, offset: int) -> str:
    if offset < 0 or offset >= len(data):
        raise ValueError(f"DBC string offset out of range: {offset}")
    end = data.find(b"\0", offset)
    if end < 0:
        raise ValueError(f"DBC string at offset {offset} is not null terminated")
    return data[offset:end].decode("latin-1", errors="replace")


def parse_rsdb(data: bytes, stem: str) -> dict:
    magic = data[:4]
    count = struct.unpack_from("<I", data, 4)[0]
    if stem in BIG_TABLES or magic == b"RSDC":
        entry_size = 12
        records = []
        table_end = 8 + count * entry_size
        if table_end > len(data):
            raise ValueError("RSDB_BIG/RSDC entry table exceeds DBC size")
        for i in range(count):
            key, path_offset = struct.unpack_from("<QI", data, 8 + i * entry_size)
            records.append({"id": key, "path": read_cstring(data, path_offset)})
    elif stem in SMALL_TABLES:
        entry_size = 8
        records = []
        table_end = 8 + count * entry_size
        if table_end > len(data):
            raise ValueError("RSDB_SMALL entry table exceeds DBC size")
        for i in range(count):
            key, path_offset = struct.unpack_from("<II", data, 8 + i * entry_size)
            records.append({"id": key, "path": read_cstring(data, path_offset)})
    else:
        return {"format": magic.decode("ascii", errors="replace"), "record_count": count,
                "parse_status": "UNKNOWN_RSDB_KEY_WIDTH"}
    return {"format": magic.decode("ascii", errors="replace"), "record_count": count,
            "entry_size": entry_size, "parse_status": "PARSED",
            "sample_records": records[:20], "_records": records}


def parse_mesh(data: bytes) -> dict:
    """Parse legacy MESH and Mobile MESZ equipment records.

    MESH uses 16-byte parts. Mobile MESZ extends every part with eight raw
    float32 values (32 bytes); preserve them without assigning guessed semantics.
    """
    if len(data) < 8:
        raise ValueError("MESH table is shorter than its header")
    magic = data[:4]
    if magic not in (b"MESH", b"MESZ"):
        raise ValueError(f"Unsupported MESH identifier: {magic!r}")
    count = struct.unpack_from("<I", data, 4)[0]
    offset = 8
    records = []
    for index in range(count):
        if offset + 8 > len(data):
            raise ValueError(f"MESH record {index} header exceeds table size at offset {offset}")
        unique_id, part_count = struct.unpack_from("<II", data, offset)
        offset += 8
        if part_count > 64:
            raise ValueError(f"MESH record {unique_id} has invalid part count {part_count}")
        parts = []
        for part_index in range(part_count):
            part_size = 48 if magic == b"MESZ" else 16
            if offset + part_size > len(data):
                raise ValueError(f"MESH record {unique_id} part {part_index} exceeds table size")
            mesh_id, texture_id, mix_texture_id = struct.unpack_from("<III", data, offset)
            mix_opt, asb, adb, material = struct.unpack_from("<BBBB", data, offset + 12)
            part = {
                "part_index": part_index, "mesh_id": mesh_id,
                "texture_id": texture_id, "mix_texture_id": mix_texture_id,
                "mix_option": mix_opt, "alpha_source_blend": asb,
                "alpha_destination_blend": adb, "material_id": material,
                "part_extension_f32": [],
            }
            if magic == b"MESZ":
                part["part_extension_f32"] = list(struct.unpack_from("<8f", data, offset + 16))
            parts.append(part)
            offset += part_size
        records.append({"id": unique_id, "part_count": part_count, "parts": parts})
    trailing = len(data) - offset
    if trailing:
        raise ValueError(f"MESH table has {trailing} trailing byte(s) after record {len(records)}")
    return {
        "format": magic.decode("ascii", errors="replace"),
        "record_count": count, "parse_status": "PARSED",
        "part_extension": "8 raw float32 values per MESZ part" if magic == b"MESZ" else None,
        "sample_records": records[:20], "_records": records,
    }



def parse_simo(data: bytes) -> dict:
    count = struct.unpack_from("<I", data, 4)[0]
    offset = 8
    records = []
    for _ in range(count):
        if offset + 8 > len(data):
            raise ValueError("SIMO record header exceeds DBC size")
        object_id, part_count = struct.unpack_from("<II", data, offset)
        offset += 8
        if part_count > 4096 or offset + part_count * 8 > len(data):
            raise ValueError(f"SIMO part count invalid for object {object_id}: {part_count}")
        parts = []
        for _part in range(part_count):
            part_id, texture_id = struct.unpack_from("<II", data, offset)
            offset += 8
            parts.append({"part_id": part_id, "texture_id": texture_id})
        records.append({"object_id": object_id, "part_count": part_count, "parts": parts})
    if offset != len(data):
        raise ValueError(f"SIMO table has {len(data) - offset} trailing byte(s)")
    return {"format": "SIMO", "record_count": count, "parse_status": "PARSED",
            "sample_records": records[:20], "_records": records}


def parse_wdb(data: bytes) -> dict:
    if len(data) < 16 or data[:4] != b"BDMG":
        raise ValueError("c3.wdb is missing the BDMG header")
    total_size, table_offset, entry_count = struct.unpack_from("<iiI", data, 4)
    if total_size > len(data) or total_size < 16:
        raise ValueError(f"WDB declared size is invalid: {total_size} vs {len(data)}")
    if table_offset < 16 or table_offset + entry_count * WDB_ENTRY_SIZE > len(data):
        raise ValueError("WDB entry table bounds are invalid")
    entries = []
    names = set()
    for index in range(entry_count):
        start = table_offset + index * WDB_ENTRY_SIZE
        plain = decrypt_entry_block(data[start:start + WDB_ENTRY_SIZE])
        file_hash, offset, size = struct.unpack_from("<Iii", plain, 0)
        name_bytes = plain[20:84].split(b"\0", 1)[0]
        name = name_bytes.decode("ascii", errors="replace").replace("\\", "/")
        if not name or any(ord(ch) < 32 for ch in name):
            raise ValueError(f"Decrypted WDB entry {index} has an invalid name")
        if offset < 16 or size < 0 or offset + size > len(data):
            raise ValueError(f"WDB entry {name} has invalid bounds offset={offset} size={size}")
        if name.lower() in names:
            raise ValueError(f"Duplicate WDB entry name: {name}")
        names.add(name.lower())
        blob = data[offset:offset + size]
        stem = Path(name).stem.lower()
        magic = blob[:4]
        if magic in (b"RSDB", b"RSDC"):
            parsed = parse_rsdb(blob, stem)
        elif magic == b"SIMO":
            parsed = parse_simo(blob)
        elif magic in (b"MESH", b"MESZ"):
            parsed = parse_mesh(blob)
        elif magic == b"ROPT":
            # Preserve a bounded raw probe until the Mobile RolePart record layout
            # is validated against independent samples; never guess field names.
            payload = blob[8:]
            u32_count = min(len(payload) // 4, 128)
            u16_count = min(len(payload) // 2, 128)
            parsed = {
                "format": "ROPT",
                "record_count": struct.unpack_from("<I", blob, 4)[0] if len(blob) >= 8 else None,
                "parse_status": "RAW_LAYOUT_PROBE_ONLY",
                "raw_size_bytes": len(blob),
                "payload_size_bytes": len(payload),
                "u32_probe": list(struct.unpack_from("<" + "I" * u32_count, payload, 0)) if u32_count else [],
                "u16_probe": list(struct.unpack_from("<" + "H" * u16_count, payload, 0)) if u16_count else [],
                "payload_hex": payload.hex(),
            }
        elif magic == b"SIM5":
            parsed = {
                "format": "SIM5", "record_count": struct.unpack_from("<I", blob, 4)[0] if len(blob) >= 8 else None,
                "parse_status": "RAW_LAYOUT_PROBE_ONLY", "raw_size_bytes": len(blob),
                "raw_hex": blob.hex(" ")
            }
        else:
            parsed = {"format": magic.decode("ascii", errors="replace"),
                      "record_count": struct.unpack_from("<I", blob, 4)[0] if len(blob) >= 8 else None,
                      "parse_status": "MAGIC_RECORDED_ONLY"}
        entries.append({
            "name": name, "hash": file_hash, "offset": offset, "size_bytes": size,
            "sha256": hashlib.sha256(blob).hexdigest(), "magic": magic.decode("ascii", errors="replace"),
            "parsed": parsed
        })
    # Resolve the 3DSimpleObj part references against the full 3DObj and
    # 3DTexture indexes. Keep only compact evidence in the report, not all rows.
    by_name = {entry["name"].lower(): entry for entry in entries}

    def take_rows(table_name: str) -> list:
        entry = by_name.get(table_name.lower())
        if entry is None:
            return []
        return entry["parsed"].pop("_records", [])

    object_rows = take_rows("ini/3DObj.dbc")
    texture_rows = take_rows("ini/3DTexture.dbc")
    simple_rows = take_rows("ini/3DSimpleObj.dbc")
    motion_table_names = tuple(
        entry["name"] for entry in entries
        if "motion" in entry["name"].lower() and entry["parsed"].get("parse_status") == "PARSED"
    )
    motion_table_rows = {
        name: (take_rows(name) if name.lower() != "ini/mountmotion.dbc" else take_rows(name))
        for name in motion_table_names
    }
    mount_motion_rows = motion_table_rows.get("ini/mountmotion.dbc", [])
    mesh_table_names = (
        "ini/mount.dbc", "ini/armet.dbc", "ini/armet1.dbc", "ini/armor.dbc",
        "ini/weapon.dbc", "ini/head.dbc", "ini/misc.dbc", "ini/shield.dbc",
    )
    mesh_table_rows = {name: take_rows(name) for name in mesh_table_names}
    object_map = {int(row["id"]): str(row["path"]) for row in object_rows}
    texture_map = {int(row["id"]): str(row["path"]) for row in texture_rows}

    object_duplicates = len(object_rows) - len(object_map)
    texture_duplicates = len(texture_rows) - len(texture_map)
    total_parts = object_matches = texture_matches = full_matches = 0
    missing_object_ids = set()
    missing_texture_ids = set()
    resolved_samples = []
    missing_object_references = []
    missing_texture_references = []
    simple_object_catalog = []

    for simple in simple_rows:
        catalog_parts = []
        for part in simple.get("parts", []):
            total_parts += 1
            part_id = int(part["part_id"])
            texture_id = int(part["texture_id"])
            object_path = object_map.get(part_id)
            texture_path = texture_map.get(texture_id)
            if object_path is not None:
                object_matches += 1
            else:
                missing_object_ids.add(part_id)
            if texture_path is not None:
                texture_matches += 1
            else:
                missing_texture_ids.add(texture_id)
            part_record = {
                "part_id": part_id,
                "object_path": object_path,
                "object_resolved": object_path is not None,
                "texture_id": texture_id,
                "texture_path": texture_path,
                "texture_resolved": texture_path is not None,
            }
            catalog_parts.append(part_record)
            if object_path is not None and texture_path is not None:
                full_matches += 1
                if len(resolved_samples) < 40:
                    resolved_samples.append({
                        "simple_object_id": int(simple["object_id"]),
                        **part_record,
                    })
            else:
                unresolved = {"simple_object_id": int(simple["object_id"]), **part_record}
                if object_path is None and len(missing_object_references) < 100:
                    missing_object_references.append(unresolved)
                if texture_path is None and len(missing_texture_references) < 100:
                    missing_texture_references.append(unresolved)
        simple_object_catalog.append({
            "simple_object_id": int(simple["object_id"]),
            "part_count": int(simple["part_count"]),
            "parts": catalog_parts,
        })

    # Resolve MESH family records against the 3DObj / 3DTexture path tables.
    mesh_family_catalog = {}
    full_mesh_records_by_table = {}
    for table_name, rows in mesh_table_rows.items():
        resolved_records = []
        full_records = []
        part_total = object_resolved = texture_resolved = mix_texture_resolved = fully_resolved = 0
        missing_mesh_ids = set()
        missing_texture_ids = set()
        missing_mix_texture_ids = set()
        for row in rows:
            resolved_parts = []
            for part in row.get("parts", []):
                part_total += 1
                mesh_id = int(part["mesh_id"])
                texture_id = int(part["texture_id"])
                mix_texture_id = int(part["mix_texture_id"])
                mesh_path = object_map.get(mesh_id)
                texture_path = texture_map.get(texture_id)
                mix_texture_path = texture_map.get(mix_texture_id) if mix_texture_id else None
                if mesh_path is None:
                    missing_mesh_ids.add(mesh_id)
                else:
                    object_resolved += 1
                if texture_path is None:
                    missing_texture_ids.add(texture_id)
                else:
                    texture_resolved += 1
                if mix_texture_id:
                    if mix_texture_path is None:
                        missing_mix_texture_ids.add(mix_texture_id)
                    else:
                        mix_texture_resolved += 1
                if mesh_path is not None and texture_path is not None and (not mix_texture_id or mix_texture_path is not None):
                    fully_resolved += 1
                resolved_parts.append({
                    **part, "mesh_path": mesh_path, "texture_path": texture_path,
                    "mix_texture_path": mix_texture_path,
                    "mesh_path_resolved": mesh_path is not None,
                    "texture_path_resolved": texture_path is not None,
                    "mix_texture_path_resolved": (not mix_texture_id) or mix_texture_path is not None,
                })
            full_record = {
                "unique_id": int(row["id"]), "part_count": int(row["part_count"]),
                "parts": resolved_parts,
            }
            full_records.append(full_record)
            if len(resolved_records) < 60:
                resolved_records.append(full_record)
        full_mesh_records_by_table[table_name] = full_records
        mesh_family_catalog[table_name] = {
            "record_count": len(rows), "part_count": part_total,
            "mesh_id_matches": object_resolved, "texture_id_matches": texture_resolved,
            "mix_texture_id_matches": mix_texture_resolved,
            "fully_resolved_part_count": fully_resolved,
            "missing_mesh_id_count": len(missing_mesh_ids),
            "missing_texture_id_count": len(missing_texture_ids),
            "missing_mix_texture_id_count": len(missing_mix_texture_ids),
            "missing_mesh_id_samples": sorted(missing_mesh_ids)[:30],
            "missing_texture_id_samples": sorted(missing_texture_ids)[:30],
            "missing_mix_texture_id_samples": sorted(missing_mix_texture_ids)[:30],
            "sample_records": resolved_records,
            "status": "ID_PATH_JOINED_REQUIRES_FILE_PRESENCE_AND_VISUAL_REVIEW" if rows else "TABLE_NOT_PARSED",
        }

    motion_catalog_tables = {}
    all_motion_paths = set()
    for table_name, rows in motion_table_rows.items():
        records = []
        unique_paths = set()
        for row in rows:
            motion_id = int(row.get("id", row.get("key", 0)))
            motion_path = str(row.get("path", ""))
            if motion_path:
                unique_paths.add(motion_path)
                all_motion_paths.add(motion_path)
            records.append({"motion_id": motion_id, "motion_path": motion_path})
        motion_catalog_tables[table_name] = {
            "record_count": len(rows),
            "unique_path_count": len(unique_paths),
            "records": records,
            "status": "SOURCE_ID_TO_C3_MOTION_PATH_JOINED",
        }
    motion_catalog_dir = Path("resource_stage/world/resource_mappings")
    motion_catalog_dir.mkdir(parents=True, exist_ok=True)
    motion_catalog_path = motion_catalog_dir / "motion_catalog.json"
    motion_catalog = {
        "schema_version": "1.0.0",
        "source_container_sha256": hashlib.sha256(data).hexdigest(),
        "tables": motion_catalog_tables,
        "unique_motion_path_count": len(all_motion_paths),
        "unique_motion_paths": sorted(all_motion_paths),
        "note": "Motion ID to source C3 path joins only; imported animation clips and runtime retargeting require separate validation.",
    }
    motion_catalog_path.write_text(json.dumps(motion_catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    motion_report_path = Path("reports/c3-motion-source-path-audit.json")
    motion_report_path.parent.mkdir(parents=True, exist_ok=True)
    motion_report = {
        "schema_version": "1.0.0",
        "table_summaries": {
            name: {"record_count": value["record_count"], "unique_path_count": value["unique_path_count"]}
            for name, value in motion_catalog_tables.items()
        },
        "unique_motion_path_count": len(all_motion_paths),
        "motion_catalog_path": str(motion_catalog_path),
        "motion_catalog_sha256": hashlib.sha256(motion_catalog_path.read_bytes()).hexdigest(),
        "status": "SOURCE_MOTION_PATHS_CATALOGUED_REQUIRES_C3_CONVERSION_AND_RUNTIME_ANIMATION_TEST",
    }
    motion_report_path.write_text(json.dumps(motion_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    mount_motion_by_base = {}
    for row in mount_motion_rows:
        key = int(row.get("id", row.get("key", 0)))
        base = key // 1000
        mount_motion_by_base.setdefault(base, []).append({
            "motion_key": key, "motion_path": str(row["path"])
        })
    mount_full_records = full_mesh_records_by_table.get("ini/mount.dbc", [])
    mount_motion_sets = {}
    for record in mount_full_records:
        motions = mount_motion_by_base.get(int(record["unique_id"]), [])
        if not motions or not record.get("parts"):
            continue
        base_mesh_id = str(record["parts"][0].get("mesh_id", ""))
        base_mesh_path = str(record["parts"][0].get("mesh_path", "")).replace("\\", "/").lower()
        if not base_mesh_path:
            continue
        motion_set = mount_motion_sets.setdefault(base_mesh_path, {
            "base_mesh_path": base_mesh_path,
            "base_mesh_ids": [],
            "source_record_ids": [],
            "motion_records_by_key": {},
        })
        if base_mesh_id:
            motion_set["base_mesh_ids"].append(int(base_mesh_id))
        motion_set["source_record_ids"].append(int(record["unique_id"]))
        for motion in motions:
            motion_set["motion_records_by_key"][str(motion["motion_key"])] = motion
    for base_mesh_path, motion_set in mount_motion_sets.items():
        motion_set["base_mesh_ids"] = sorted(set(motion_set["base_mesh_ids"]))
        motion_set["source_record_ids"] = sorted(set(motion_set["source_record_ids"]))
        motion_set["motion_records"] = sorted(
            motion_set.pop("motion_records_by_key").values(),
            key=lambda row: int(row["motion_key"]),
        )
        motion_set["record_count"] = len(motion_set["motion_records"])
        motion_set["unique_path_count"] = len({row["motion_path"] for row in motion_set["motion_records"] if row.get("motion_path")})
    for record in mount_full_records:
        parts = record.get("parts", [])
        base_mesh_id = str(parts[0].get("mesh_id", "")) if parts else ""
        base_mesh_path = str(parts[0].get("mesh_path", "")).replace("\\", "/").lower() if parts else ""
        record["motion_set_mesh_id"] = int(base_mesh_id) if base_mesh_path in mount_motion_sets and base_mesh_id.isdigit() else None
        record["motion_set_mesh_path"] = base_mesh_path if base_mesh_path in mount_motion_sets else None
        record["motion_set_source_record_ids"] = mount_motion_sets.get(base_mesh_path, {}).get("source_record_ids", [])
    mount_table = mesh_family_catalog.get("ini/mount.dbc", {})
    mount_motion_matches = 0
    mount_motion_unmatched = []
    for sample in mount_table.get("sample_records", []):
        parts = sample.get("parts", [])
        base_mesh_id = str(parts[0].get("mesh_id", "")) if parts else ""
        base_mesh_path = str(parts[0].get("mesh_path", "")).replace("\\", "/").lower() if parts else ""
        sample["motion_set_mesh_id"] = int(base_mesh_id) if base_mesh_path in mount_motion_sets and base_mesh_id.isdigit() else None
        sample["motion_set_mesh_path"] = base_mesh_path if base_mesh_path in mount_motion_sets else None
        if base_mesh_path in mount_motion_sets:
            mount_motion_matches += 1
        elif len(mount_motion_unmatched) < 60:
            mount_motion_unmatched.append(int(sample["unique_id"]))
    mount_table["mount_motion_base_divisor"] = 1000
    mount_table["mount_motion_matched_sample_count"] = mount_motion_matches
    mount_table["mount_motion_unmatched_sample_ids"] = mount_motion_unmatched
    mount_table["mount_motion_record_count"] = len(mount_motion_rows)
    mount_table["mount_motion_set_count"] = len(mount_motion_sets)
    mount_table["mount_motion_status"] = "MOUNTMOTION_JOIN_PROPAGATED_TO_VARIANTS_BY_SHARED_BASE_MESH_ID_REQUIRES_RUNTIME_PLAYBACK"

    catalog_dir = Path("resource_stage/world/resource_mappings")
    catalog_dir.mkdir(parents=True, exist_ok=True)
    equipment_catalog_path = catalog_dir / "mesh_equipment_catalog.json"
    equipment_catalog = {
        "schema_version": "1.0.0",
        "source_container_sha256": hashlib.sha256(data).hexdigest(),
        "source_tables": list(mesh_table_names) + ["ini/3DObj.dbc", "ini/3DTexture.dbc"] + list(motion_table_names),
        "motion_catalog_path": str(motion_catalog_path),
        "motion_catalog_sha256": hashlib.sha256(motion_catalog_path.read_bytes()).hexdigest(),
        "schema_status": "MESH_ID_TO_C3_AND_TEXTURE_PATH_LINKED",
        "tables": {
            table_name: {
                "record_count": len(records),
                "records": records,
                "status": mesh_family_catalog[table_name]["status"],
            }
            for table_name, records in full_mesh_records_by_table.items()
        },
        "mount_motion_sets": mount_motion_sets,
        "mount_motion_join": {
            "rule": "mountmotion key // 1000 == mount.dbc unique ID; propagate the resulting animation set to mount variants sharing the same resolved first-part C3 mesh path",
            "status": "SOURCE_ID_JOIN_AND_SHARED_BASE_MESH_PATH_PROPAGATION_REQUIRES_RUNTIME_PLAYBACK",
            "record_count": len(mount_motion_rows),
            "motion_set_count": len(mount_motion_sets),
        },
        "note": "Source ID/path catalog only. Mobile MESZ part extensions are preserved as eight raw float32 values per part. Texture file presence, C3 geometry correctness, rig attachment and runtime rendering are validated separately."
    }
    equipment_catalog_path.write_text(json.dumps(equipment_catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    catalog_path = catalog_dir / "simple_object_catalog.json"
    catalog_data = {
        "schema_version": "1.0.0",
        "source_container_sha256": hashlib.sha256(data).hexdigest(),
        "source_table": "ini/3DSimpleObj.dbc",
        "reference_tables": ["ini/3DObj.dbc", "ini/3DTexture.dbc"],
        "schema_status": "SOURCE_ID_PATH_MAPPING_ONLY",
        "object_count": len(simple_object_catalog),
        "part_count": total_parts,
        "fully_resolved_part_count": full_matches,
        "objects": simple_object_catalog,
        "note": "This catalog resolves source IDs to C3/PVR paths. It does not assert correct mesh assembly, UVs, transforms, materials or visual acceptance.",
    }
    catalog_path.write_text(json.dumps(catalog_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    resource_reference_audit = {
        "schema_status": "CROSS_REFERENCED_BY_SOURCE_IDS",
        "table_counts": {
            "3DObj": len(object_rows),
            "3DTexture": len(texture_rows),
            "3DSimpleObj": len(simple_rows),
        },
        "duplicate_ids": {
            "3DObj": object_duplicates,
            "3DTexture": texture_duplicates,
        },
        "simple_object_parts": total_parts,
        "object_id_matches": object_matches,
        "object_id_match_percent": round(100.0 * object_matches / total_parts, 2) if total_parts else 0.0,
        "texture_id_matches": texture_matches,
        "texture_id_match_percent": round(100.0 * texture_matches / total_parts, 2) if total_parts else 0.0,
        "both_object_and_texture_match": full_matches,
        "fully_resolved_percent": round(100.0 * full_matches / total_parts, 2) if total_parts else 0.0,
        "missing_object_id_count": len(missing_object_ids),
        "missing_texture_id_count": len(missing_texture_ids),
        "missing_object_id_samples": sorted(missing_object_ids)[:40],
        "missing_texture_id_samples": sorted(missing_texture_ids)[:40],
        "missing_object_reference_samples": missing_object_references,
        "missing_texture_reference_samples": missing_texture_references,
        "resolved_samples": resolved_samples,
        "simple_object_catalog_path": str(catalog_path),
        "simple_object_catalog_sha256": hashlib.sha256(catalog_path.read_bytes()).hexdigest(),
        "note": "ID-level joins only; C3 geometry, UV/material correctness and rendered appearance still require separate validation.",
    }

    return {
        "magic": "BDMG", "file_size_bytes": len(data), "declared_size_bytes": total_size,
        "table_offset": table_offset, "entry_count": entry_count,
        "table_end": table_offset + entry_count * WDB_ENTRY_SIZE,
        "mesh_family_catalog": mesh_family_catalog,
        "mesh_equipment_catalog_path": str(equipment_catalog_path),
        "mesh_equipment_catalog_sha256": hashlib.sha256(equipment_catalog_path.read_bytes()).hexdigest(),
        "mount_model_motion_audit": {
            "mount_mesh_record_count": mesh_family_catalog.get("ini/mount.dbc", {}).get("record_count", 0),
            "mount_mesh_part_count": mesh_family_catalog.get("ini/mount.dbc", {}).get("part_count", 0),
            "mount_motion_record_count": len(mount_motion_rows),
            "mount_motion_join_rule": "mountmotion key // 1000 == mount.dbc unique ID; candidate join only until validated against exact Mobile client runtime",
            "mount_motion_matched_sample_count": mount_motion_matches,
            "mount_motion_unmatched_sample_ids": mount_motion_unmatched,
            "note": "MESH records resolve part mesh/texture IDs through 3DObj and 3DTexture path tables. File existence and rendered fit remain separate gates."
        },
        "resource_reference_audit": resource_reference_audit,
        "motion_source_path_audit": motion_report,
        "entries": entries
    }


def main() -> None:
    candidates = sorted(Path("resource_stage").rglob("c3.wdb"))
    if len(candidates) != 1:
        raise SystemExit(f"Expected exactly one staged c3.wdb, found {len(candidates)}: {[str(p) for p in candidates[:5]]}")
    path = candidates[0]
    data = path.read_bytes()
    # Verify the block cipher independently before trusting the archive table.
    sample = bytes((i * 37 + 11) & 0xFF for i in range(WDB_ENTRY_SIZE))
    if decrypt_entry_block(encrypt_entry_block(sample)) != sample:
        raise SystemExit("WDB block cipher self-test failed")
    report = parse_wdb(data)
    report["source_path"] = str(path)
    report["source_sha256"] = hashlib.sha256(data).hexdigest()
    report["cipher_self_test"] = "PASSED"
    report["note"] = "Metadata-only WDB/DBC audit; no original DBC blobs are copied into public artifacts."
    out = Path("reports/c3-wdb-audit.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"WDB audit: {report['entry_count']} DBC entries parsed from {report['file_size_bytes']} bytes")
    for entry in report["entries"]:
        parsed = entry["parsed"]
        print(f"  {entry['name']}: {entry['magic']} records={parsed.get('record_count')} status={parsed.get('parse_status')}")
        if entry["magic"] == "MESZ":
            print(f"    MESZ_PROBE header={parsed.get('header_hex')} errors={parsed.get('parse_errors')} u32={parsed.get('u32_probe')} f32={parsed.get('f32_probe')}")
    print(f"WDB metadata report written: {out}")


if __name__ == "__main__":
    main()
