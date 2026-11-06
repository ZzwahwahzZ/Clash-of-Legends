#!/usr/bin/env python3
"""Forensic audit of GLB skin skeletons, hierarchy, weights and embedded animations."""
from __future__ import annotations
import argparse, json, struct, zipfile
from pathlib import Path

GLB_MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A
MAX_DEPTH = 5

def glb_json(data: bytes) -> dict:
    if len(data) < 20 or data[:4] != GLB_MAGIC:
        raise ValueError("not a GLB v2 file")
    version, total = struct.unpack_from("<II", data, 4)
    if version != 2 or total > len(data):
        raise ValueError(f"unsupported GLB header version={version} total={total} actual={len(data)}")
    offset = 12
    while offset + 8 <= total:
        length, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        end = offset + length
        if end > total:
            raise ValueError("chunk exceeds declared GLB length")
        if kind == JSON_CHUNK:
            return json.loads(data[offset:end].decode("utf-8").rstrip(" \t\r\n\0"))
        offset = end
    raise ValueError("GLB JSON chunk missing")

def inspect_doc(doc: dict) -> dict:
    nodes = doc.get("nodes", [])
    parents = {}
    for pi, node in enumerate(nodes):
        for child in node.get("children", []):
            parents.setdefault(child, []).append(pi)
    def nname(i):
        return nodes[i].get("name", f"node_{i}") if isinstance(i, int) and 0 <= i < len(nodes) else None
    skins = []
    for si, skin in enumerate(doc.get("skins", [])):
        joints = []
        for ji in skin.get("joints", []):
            joints.append({
                "node": ji, "name": nname(ji),
                "parent_nodes": parents.get(ji, []),
                "parent_names": [nname(p) for p in parents.get(ji, [])],
                "children": nodes[ji].get("children", []) if 0 <= ji < len(nodes) else []
            })
        skins.append({
            "skin_index": si, "name": skin.get("name"),
            "skeleton_root": skin.get("skeleton"),
            "skeleton_root_name": nname(skin.get("skeleton")),
            "joint_count": len(joints), "joints": joints,
            "inverse_bind_matrices_accessor": skin.get("inverseBindMatrices")
        })
    animations = []
    for ai, anim in enumerate(doc.get("animations", [])):
        paths = {}
        target_nodes = set()
        for channel in anim.get("channels", []):
            target = channel.get("target", {})
            path = target.get("path", "unknown")
            node = target.get("node")
            paths[path] = paths.get(path, 0) + 1
            if node is not None: target_nodes.add(node)
        animations.append({
            "animation_index": ai, "name": anim.get("name"),
            "sampler_count": len(anim.get("samplers", [])),
            "channel_count": len(anim.get("channels", [])),
            "channels_by_path": paths,
            "target_nodes": [{"node": i, "name": nname(i)} for i in sorted(target_nodes)]
        })
    primitive_count = 0
    weighted_primitives = 0
    joint_attributes = []
    for mesh in doc.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive_count += 1
            attrs = primitive.get("attributes", {})
            if "JOINTS_0" in attrs or "WEIGHTS_0" in attrs:
                weighted_primitives += 1
                joint_attributes.append({
                    "mesh": mesh.get("name"),
                    "joints_0_accessor": attrs.get("JOINTS_0"),
                    "weights_0_accessor": attrs.get("WEIGHTS_0")
                })
    return {
        "asset": doc.get("asset", {}),
        "scene_count": len(doc.get("scenes", [])),
        "node_count": len(nodes),
        "mesh_count": len(doc.get("meshes", [])),
        "primitive_count": primitive_count,
        "weighted_primitive_count": weighted_primitives,
        "skins": skins,
        "animations": animations,
        "joint_weight_attributes": joint_attributes,
        "node_names": [{"node": i, "name": n.get("name")} for i, n in enumerate(nodes) if n.get("name")]
    }

def walk(zf, container, depth, results, errors):
    if depth > MAX_DEPTH: return
    for info in zf.infolist():
        if info.is_dir(): continue
        name = info.filename
        try:
            if name.lower().endswith(".glb"):
                raw = zf.read(info)
                doc = glb_json(raw)
                results.append({
                    "container": container, "path": name,
                    "size_bytes": len(raw), **inspect_doc(doc)
                })
            elif depth < MAX_DEPTH and name.lower().endswith((".zip", ".apk", ".jar")):
                with zf.open(info) as stream:
                    import tempfile
                    with tempfile.NamedTemporaryFile(suffix=Path(name).suffix) as tmp:
                        while True:
                            block = stream.read(1024 * 1024)
                            if not block: break
                            tmp.write(block)
                        tmp.flush()
                        try:
                            with zipfile.ZipFile(tmp.name) as nested:
                                walk(nested, container + "!" + name, depth + 1, results, errors)
                        except zipfile.BadZipFile:
                            pass
        except Exception as exc:
            errors.append({"container": container, "path": name, "error": f"{type(exc).__name__}: {exc}"})

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("archive", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    results, errors = [], []
    with zipfile.ZipFile(args.archive) as outer:
        walk(outer, args.archive.name, 0, results, errors)
    summary = {
        "schema_version": "1.0.0",
        "source_archive": args.archive.name,
        "glb_file_count": len(results),
        "skinned_glb_count": sum(bool(x["skins"]) for x in results),
        "animated_glb_count": sum(bool(x["animations"]) for x in results),
        "glb_with_both_skin_and_animation_count": sum(bool(x["skins"]) and bool(x["animations"]) for x in results),
        "total_skin_count": sum(len(x["skins"]) for x in results),
        "total_embedded_animation_count": sum(len(x["animations"]) for x in results),
        "total_joint_count": sum(s["joint_count"] for x in results for s in x["skins"]),
        "errors": errors,
        "files": results
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in summary.items() if k not in ("files",)}, ensure_ascii=False))
if __name__ == "__main__":
    main()
