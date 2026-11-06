#!/usr/bin/env python3
"""Audit PUL/PUX -> ANI -> decoded MJP texture coverage for source maps."""
from __future__ import annotations
import argparse, collections, json, struct
from pathlib import Path

def fixed(data):
    return data.split(b"\0", 1)[0].decode("cp1252", errors="replace")

def u16(data, pos):
    if pos + 2 > len(data): raise ValueError("truncated uint16")
    return struct.unpack_from("<H", data, pos)[0], pos + 2

def u32(data, pos):
    if pos + 4 > len(data): raise ValueError("truncated uint32")
    return struct.unpack_from("<I", data, pos)[0], pos + 4

def parse_ani(path):
    sections, current = {}, None
    for raw in path.read_bytes().decode("cp1252", errors="replace").splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1].lower()
            sections[current] = []
        elif current and line.lower().startswith("frame") and "=" in line:
            sections[current].append(line.split("=", 1)[1].strip().replace("\\", "/").lower())
    return sections

def index_ani(root):
    out = collections.defaultdict(list)
    for path in root.rglob("*.ani"):
        try: out[path.name.lower()].append((path, parse_ani(path)))
        except Exception: pass
    return out

def resolve_frames(ani_path, piece_name, ani_index, mjp):
    name = Path(ani_path.replace("\\", "/")).name.lower()
    candidates = ani_index.get(name, [])
    if not candidates: return "ANI_FILE_MISSING", [], []
    frames = candidates[0][1].get(piece_name.lower(), [])
    if not frames: return "ANI_SECTION_MISSING", [], []
    found = [f for f in frames if f.replace("\\", "/").lower() in mjp]
    missing = [f for f in frames if f.replace("\\", "/").lower() not in mjp]
    return ("DECODED" if not missing else "MJP_TEXTURE_MISSING"), found, missing

def parse_pul(path, ani_index, mjp):
    data, pos = path.read_bytes(), 0
    header = fixed(data[pos:pos+8]); pos += 8
    ani_path = fixed(data[pos:pos+256]); pos += 256
    width, height = struct.unpack_from("<II", data, pos); pos += 8
    if not (1 <= width <= 8192 and 1 <= height <= 8192) or width*height > 20_000_000:
        raise ValueError(f"implausible dimensions {width}x{height}")
    count = width*height
    if pos + count*2 > len(data): raise ValueError("truncated tile grid")
    tiles = struct.unpack_from(f"<{count}H", data, pos); pos += count*2
    roll = None
    if header != "PUZZLE" and pos + 8 <= len(data):
        roll = struct.unpack_from("<ii", data, pos); pos += 8
    unique = sorted(set(tiles))
    resolved = missing_ani = missing_mjp = frame_count = decoded_frames = 0
    for tile in unique:
        status, found, missing = resolve_frames(ani_path, f"Puzzle{tile}", ani_index, mjp)
        frame_count += len(found) + len(missing); decoded_frames += len(found)
        if status == "DECODED": resolved += 1
        elif status == "ANI_FILE_MISSING" or status == "ANI_SECTION_MISSING": missing_ani += 1
        else: missing_mjp += 1
    return {"file": path.name, "path": str(path), "header": header, "ani_path": ani_path,
            "width": width, "height": height, "tile_count": count,
            "nonzero_tiles": sum(1 for x in tiles if x), "unique_tile_ids": len(unique),
            "resolved_tile_ids": resolved, "missing_ani_tile_ids": missing_ani,
            "missing_mjp_tile_ids": missing_mjp, "frame_count": frame_count,
            "decoded_frames": decoded_frames,
            "tile_coverage": round(resolved/len(unique), 6) if unique else 0.0,
            "frame_coverage": round(decoded_frames/frame_count, 6) if frame_count else 0.0,
            "roll_speed": roll, "trailing_bytes": len(data)-pos}

def parse_pux(path, ani_index, mjp):
    data, pos = path.read_bytes(), 0
    puzzle_type = fixed(data[:16]); pos = 16
    token, pos = u32(data, pos)
    width, height = struct.unpack_from("<II", data, pos); pos += 8
    _unknown, pos = u32(data, pos)
    if not (1 <= width <= 8192 and 1 <= height <= 8192) or width*height > 20_000_000:
        raise ValueError(f"implausible dimensions {width}x{height}")
    group_count, pos = u16(data, pos)
    groups = []
    for _ in range(group_count):
        n, pos = u16(data, pos); pos += n
        n, pos = u16(data, pos); ani = fixed(data[pos:pos+n]); pos += n
        n, pos = u16(data, pos); piece = fixed(data[pos:pos+n]); pos += n
        values = struct.unpack_from("<5I", data, pos); pos += 20
        groups.append((ani, piece, values))
    _edge_token, pos = u32(data, pos)
    edge_count, pos = u16(data, pos)
    for _ in range(edge_count):
        n, pos = u16(data, pos); pos += n
        n, pos = u16(data, pos); pos += n
        n, pos = u16(data, pos); pos += n
        pos += 20
    grid_count, pos = u32(data, pos)
    if grid_count != width*height: raise ValueError("grid count mismatch")
    used = collections.Counter()
    for _ in range(grid_count):
        count = data[pos]; pos += 1
        for _ in range(count):
            idx, pos = u16(data, pos)
            _unknown, pos = u32(data, pos)
            used[idx] += 1
    edge_data, pos = u32(data, pos); pos += edge_data*8
    if pos != len(data): raise ValueError(f"{len(data)-pos} trailing bytes")
    resolved = missing = missing_ani = missing_mjp = frame_count = decoded_frames = 0
    for idx, layers in used.items():
        if idx >= len(groups): missing += layers; continue
        ani, piece, _ = groups[idx]
        status, found, absent = resolve_frames(ani, piece, ani_index, mjp)
        frame_count += (len(found)+len(absent))*layers; decoded_frames += len(found)*layers
        if status == "DECODED": resolved += layers
        else:
            missing += layers
            if status in ("ANI_FILE_MISSING", "ANI_SECTION_MISSING"): missing_ani += layers
            else: missing_mjp += layers
    total = sum(used.values())
    return {"file": path.name, "path": str(path), "puzzle_type": puzzle_type,
            "token": token, "width": width, "height": height,
            "texture_groups": group_count, "occupied_group_indices": len(used),
            "piece_layers": total, "resolved_piece_layers": resolved,
            "missing_piece_layers": missing, "missing_ani_piece_layers": missing_ani,
            "missing_mjp_piece_layers": missing_mjp, "frame_count_weighted": frame_count,
            "decoded_frames_weighted": decoded_frames,
            "piece_coverage": round(resolved/total, 6) if total else 0.0,
            "frame_coverage": round(decoded_frames/frame_count, 6) if frame_count else 0.0}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, required=True)
    ap.add_argument("--mjp-map", type=Path, required=True)
    ap.add_argument("--map-audit", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    mapping = json.loads(args.mjp_map.read_text(encoding="utf-8"))
    mjp = {k.replace("\\", "/").lower() for k in mapping["entries"]}
    ani_index = index_ani(args.root)
    pul, pux, failures = [], [], []
    for path in args.root.rglob("*.pul"):
        try: pul.append(parse_pul(path, ani_index, mjp))
        except Exception as exc: failures.append({"path": str(path), "format": "PUL", "error": str(exc)[:240]})
    for path in args.root.rglob("*.pux"):
        try: pux.append(parse_pux(path, ani_index, mjp))
        except Exception as exc: failures.append({"path": str(path), "format": "PUX", "error": str(exc)[:240]})
    by_name = {x["file"].lower(): x for x in pul+pux}
    map_audit = json.loads(args.map_audit.read_text(encoding="utf-8"))
    maps = []
    for item in map_audit.get("maps", []):
        logical = Path(str(item.get("puzzle_path", "")).replace("\\", "/")).name.lower()
        puzzle = by_name.get(logical)
        if puzzle:
            maps.append({"map_id": item.get("map_id"), "map_path": item.get("path"),
                         "map_size": [item.get("width"), item.get("height")],
                         "puzzle_path": item.get("puzzle_path"), "puzzle_file": puzzle["file"],
                         "puzzle_grid": [puzzle["width"], puzzle["height"]],
                         "texture_coverage": puzzle.get("piece_coverage", puzzle.get("tile_coverage", 0)),
                         "frame_coverage": puzzle.get("frame_coverage", 0),
                         "resolved_layers": puzzle.get("resolved_piece_layers", puzzle.get("resolved_tile_ids", 0)),
                         "total_layers": puzzle.get("piece_layers", puzzle.get("unique_tile_ids", 0))})
    maps.sort(key=lambda x: (x["texture_coverage"], x["frame_coverage"], x["map_size"][0] or 0), reverse=True)
    result = {"format": "PUL/PUX -> ANI -> decoded MJP coverage",
              "ani_files_indexed": sum(len(v) for v in ani_index.values()),
              "mjp_texture_entries": len(mjp), "pul_files": len(pul),
              "pux_files": len(pux), "failed_files": len(failures),
              "maps_with_puzzle_match": len(maps), "best_maps": maps[:50],
              "pul_results": pul, "pux_results": pux, "failures": failures[:250]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"pul_files": len(pul), "pux_files": len(pux),
                      "ani_files_indexed": result["ani_files_indexed"],
                      "mjp_texture_entries": len(mjp), "failed_files": len(failures),
                      "best_maps": maps[:12]}, ensure_ascii=False))
if __name__ == "__main__": main()
