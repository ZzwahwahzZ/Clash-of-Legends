#!/usr/bin/env python3
"""Audit Conquer-style DMAP/PUX/ANI source files without modifying them."""
from __future__ import annotations
import argparse
import collections
import json
import struct
from pathlib import Path


class Reader:
    def __init__(self, data: bytes, label: str):
        self.data = data
        self.pos = 0
        self.label = label

    def take(self, n: int) -> bytes:
        if n < 0 or self.pos + n > len(self.data):
            raise ValueError(f"{self.label}: truncated at 0x{self.pos:x}, need {n} bytes")
        out = self.data[self.pos:self.pos+n]
        self.pos += n
        return out

    def unpack(self, fmt: str):
        return struct.unpack(fmt, self.take(struct.calcsize(fmt)))

    def u8(self): return self.unpack("<B")[0]
    def u16(self): return self.unpack("<H")[0]
    def i16(self): return self.unpack("<h")[0]
    def u32(self): return self.unpack("<I")[0]
    def i32(self): return self.unpack("<i")[0]
    def u64(self): return self.unpack("<Q")[0]

    def fixed_string(self, n: int) -> str:
        return self.take(n).split(b"\0", 1)[0].decode("cp1252", errors="replace")


def parse_dmap(path: Path) -> dict:
    r = Reader(path.read_bytes(), "DMAP")
    version, header_value = r.unpack("<II")
    puzzle_path = r.fixed_string(260)
    width, height = r.unpack("<II")
    if not (1 <= width <= 8192 and 1 <= height <= 8192) or width * height > 20_000_000:
        raise ValueError(f"DMAP: implausible dimensions {width}x{height}")

    no_access = collections.Counter()
    surfaces = collections.Counter()
    heights = []
    row_checksums = []
    walkable = blocked = 0
    for _y in range(height):
        for _x in range(width):
            access, surface, elevation = r.unpack("<H H h")
            no_access[access] += 1
            surfaces[surface] += 1
            heights.append(elevation)
            if access == 1:
                blocked += 1
            else:
                walkable += 1
        row_checksums.append(r.u32())

    portal_count = r.i32()
    if not 0 <= portal_count <= 1_000_000:
        raise ValueError(f"DMAP: implausible portal count {portal_count}")
    for _ in range(portal_count):
        r.take(12)

    pre_items = collections.Counter()
    pre_cover_paths = collections.Counter()
    pre_cover_names = collections.Counter()
    pre_item_count = 0
    if version >= 0x3EE:
        pre_item_count = r.u32()
        if pre_item_count > 2_000_000:
            raise ValueError("DMAP: implausible pre-item count")
        for _ in range(pre_item_count):
            item_type = r.u32()
            pre_items[item_type] += 1
            if item_type == 0x18:
                ani_path = r.fixed_string(260)
                ani_name = r.fixed_string(128)
                r.take(8 + 8 + 8 + 4 + 4)
                pre_cover_paths[ani_path] += 1
                pre_cover_names[ani_name] += 1
            else:
                raise ValueError(f"DMAP: unsupported pre-item type 0x{item_type:x} at 0x{r.pos-4:x}")

    object_count = r.i32()
    if not 0 <= object_count <= 2_000_000:
        raise ValueError(f"DMAP: implausible map object count {object_count}")
    objects = collections.Counter()
    cover_paths = collections.Counter()
    ani_names = collections.Counter()
    for _ in range(object_count):
        obj_type = r.u32()
        objects[obj_type] += 1
        if obj_type == 0x01:       # Terrain
            r.take(260 + 8)
        elif obj_type == 0x03:     # MapScene
            r.take(260 + 128 + 6 * 4)
        elif obj_type == 0x04:     # Cover
            ani_path = r.fixed_string(260)
            ani_name = r.fixed_string(128)
            r.take(8 + 8 + 8 + 4)
            if version > 0x3EC:
                r.u32()
            cover_paths[ani_path] += 1
            ani_names[ani_name] += 1
        elif obj_type == 0x08:     # Puzzle
            r.take(260)
        elif obj_type == 0x0A:     # Effect
            r.take(64 + 8)
        elif obj_type == 0x0F:     # Sound
            r.take(260 + 8 + 4 + 4)
        elif obj_type == 0x13:     # EffectNew
            r.take(60 + 8 + 7 * 4)
        elif obj_type == 0x18:     # Unknown1
            r.take(260 + 128 + 2 + 2 + 8 * 4)
        elif obj_type == 0x1B:     # Unknown2
            r.take(260 + 4 + 8)
        else:
            raise ValueError(f"DMAP: unsupported object type 0x{obj_type:x} at 0x{r.pos-4:x}")

    layer_count = r.i32()
    if not 0 <= layer_count <= 100_000:
        raise ValueError(f"DMAP: implausible layer count {layer_count}")
    layer_types = collections.Counter()
    layer_objects = collections.Counter()
    for _ in range(layer_count):
        r.u32()
        layer_type = r.u32()
        layer_types[layer_type] += 1
        if layer_type != 4:
            raise ValueError(f"DMAP: unsupported layer type {layer_type}")
        r.take(8)
        if version > 0x3EC:
            r.take(12)
        layer_object_count = r.u32()
        if layer_object_count > 2_000_000:
            raise ValueError("DMAP: implausible layer object count")
        for _ in range(layer_object_count):
            obj_type = r.u32()
            layer_objects[obj_type] += 1
            if obj_type == 0x01:
                r.take(260 + 8)
            elif obj_type == 0x03:
                r.take(260 + 128 + 6 * 4)
            elif obj_type == 0x08:
                r.take(260)
            elif obj_type == 0x0A:
                r.take(64 + 8)
            elif obj_type == 0x13:
                r.take(60 + 8 + 7 * 4)
            else:
                raise ValueError(f"DMAP: unsupported layer object type 0x{obj_type:x}")

    if version > 0x3EC:
        r.take(8)
    trailing = len(r.data) - r.pos
    if trailing:
        raise ValueError(f"DMAP: {trailing} unexplained trailing bytes")

    return {
        "file": path.name, "size_bytes": len(r.data), "version": version,
        "header_value": header_value, "puzzle_path": puzzle_path,
        "width": width, "height": height, "tile_count": width * height,
        "walkable_tiles": walkable, "blocked_tiles": blocked,
        "no_access_counts": dict(no_access), "surface_counts": dict(surfaces.most_common()),
        "elevation_min": min(heights), "elevation_max": max(heights),
        "row_checksum_count": len(row_checksums), "portal_count": portal_count,
        "pre_item_count": pre_item_count, "pre_item_types": dict(pre_items),
        "pre_cover_animation_paths": dict(pre_cover_paths),
        "pre_cover_name_samples": pre_cover_names.most_common(20),
        "map_object_count": object_count, "map_object_types": dict(objects),
        "cover_animation_paths": dict(cover_paths),
        "cover_name_samples": ani_names.most_common(20),
        "layer_count": layer_count, "layer_types": dict(layer_types),
        "layer_object_types": dict(layer_objects),
        "parsed_bytes": r.pos, "trailing_bytes": trailing,
    }


def parse_pux(path: Path) -> dict:
    r = Reader(path.read_bytes(), "PUX")
    puzzle_type = r.fixed_string(16)
    token = r.u32()
    width, height = r.unpack("<II")
    unknown_token = r.u32()
    if not (1 <= width <= 8192 and 1 <= height <= 8192) or width * height > 20_000_000:
        raise ValueError(f"PUX: implausible dimensions {width}x{height}")
    group_count = r.u16()
    groups = []
    for _ in range(group_count):
        unknown_bytes = r.take(r.u16())
        ani_file = r.fixed_string(r.u16())
        piece_name = r.fixed_string(r.u16())
        unknown_values = r.unpack("<5I")
        groups.append({"ani_file": ani_file, "piece": piece_name,
                       "unknown_bytes_length": len(unknown_bytes),
                       "unknown_values": unknown_values})
    edge_token = r.u32()
    edge_group_count = r.u16()
    edge_groups = []
    for _ in range(edge_group_count):
        unknown_bytes = r.take(r.u16())
        ani_file = r.fixed_string(r.u16())
        piece_name = r.fixed_string(r.u16())
        unknown_values = r.unpack("<5I")
        edge_groups.append({"ani_file": ani_file, "piece": piece_name,
                            "unknown_bytes_length": len(unknown_bytes),
                            "unknown_values": unknown_values})
    grid_count = r.u32()
    if grid_count != width * height:
        raise ValueError(f"PUX: grid count {grid_count} != dimensions {width}x{height}")
    occupied = 0
    piece_layers = 0
    ani_ids = collections.Counter()
    for _ in range(grid_count):
        count = r.u8()
        if count:
            occupied += 1
            for _ in range(count):
                ani_id = r.u16()
                r.i32()
                piece_layers += 1
                ani_ids[ani_id] += 1
    edge_data_count = r.u32()
    for _ in range(edge_data_count):
        r.u32()
        r.take(4)
    if r.pos != len(r.data):
        raise ValueError(f"PUX: {len(r.data)-r.pos} unexplained trailing bytes")
    ani_files = sorted({g["ani_file"] for g in groups + edge_groups})
    return {
        "file": path.name, "size_bytes": len(r.data), "puzzle_type": puzzle_type,
        "token": token, "width": width, "height": height,
        "unknown_token": unknown_token, "texture_group_count": group_count,
        "edge_token": edge_token, "edge_group_count": edge_group_count,
        "grid_count": grid_count, "occupied_cells": occupied,
        "piece_layers": piece_layers, "ani_id_counts": dict(ani_ids.most_common()),
        "ani_files": ani_files, "piece_name_samples": [g["piece"] for g in groups[:20]],
        "edge_data_count": edge_data_count, "parsed_bytes": r.pos,
    }


def parse_ani(path: Path) -> dict:
    text = path.read_bytes().decode("cp1252", errors="replace")
    sections = {}
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections[current] = []
        elif current and line.lower().startswith("frame") and "=" in line:
            sections[current].append(line.split("=", 1)[1].strip())
    return {
        "file": path.name, "size_bytes": path.stat().st_size,
        "animation_count": len(sections),
        "frame_count": sum(len(v) for v in sections.values()),
        "animation_samples": [{"name": k, "frames": v[:8]} for k, v in list(sections.items())[:20]],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dmap", required=True, type=Path)
    ap.add_argument("--pux", required=True, type=Path)
    ap.add_argument("--pux-name", default="", help="Logical source filename when the exported artifact has a generic name")
    ap.add_argument("--ani", action="append", default=[], type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    dmap = parse_dmap(args.dmap)
    pux = parse_pux(args.pux)
    ani = [parse_ani(p) for p in args.ani]
    embedded = Path(dmap["puzzle_path"].replace("\\", "/")).name.lower()
    supplied_name = (args.pux_name or args.pux.name).lower()
    if embedded != supplied_name:
        raise SystemExit(f"DMAP references {embedded}, supplied PUX source is {supplied_name}")
    result = {"status": "PARSED", "dmap": dmap, "pux": pux, "ani": ani}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "status": result["status"],
        "map": f'{dmap["width"]}x{dmap["height"]}',
        "walkable": dmap["walkable_tiles"],
        "blocked": dmap["blocked_tiles"],
        "pre_cover_records": dmap["pre_item_types"].get(24, 0),
        "map_cover_records": dmap["map_object_types"].get(4, 0),
        "pux_grid": f'{pux["width"]}x{pux["height"]}',
        "occupied_puzzle_cells": pux["occupied_cells"],
        "piece_layers": pux["piece_layers"],
        "ani_files": pux["ani_files"],
        "ani_files_parsed": len(ani),
    }, ensure_ascii=False))
if __name__ == "__main__":
    main()
