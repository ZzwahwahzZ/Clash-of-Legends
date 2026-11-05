#!/usr/bin/env python3
"""Decode supported PVR pixel formats with vectorized NumPy channel extraction."""
from __future__ import annotations
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image

def channel(values: np.ndarray, mask: int) -> np.ndarray:
    if mask == 0:
        return np.full(values.shape, 255, dtype=np.uint8)
    shift = (mask & -mask).bit_length() - 1
    bits = mask.bit_count()
    maximum = (1 << bits) - 1
    raw = (values & np.uint32(mask)) >> np.uint32(shift)
    scaled = (raw.astype(np.uint64) * 255 + maximum // 2) // maximum
    return scaled.astype(np.uint8)

decoded = []
failed = []
root = Path("build/pvr-source")
out = Path("build/pvr-png")
for path in sorted(root.rglob("*.pvr")):
    data = path.read_bytes()
    try:
        if len(data) < 52 or data[44:48] != b"PVR!":
            raise ValueError("unsupported PVR header")
        header_size, height, width, mips, flags, data_size, bpp, rmask, gmask, bmask, amask, magic, surfaces = struct.unpack_from("<13I", data, 0)
        if header_size < 52 or header_size > len(data) or width < 1 or height < 1:
            raise ValueError("invalid dimensions or header size")
        if bpp not in (16, 24, 32):
            raise ValueError(f"unsupported pixel depth {bpp}")
        bytes_per_pixel = bpp // 8
        needed = width * height * bytes_per_pixel
        start = header_size
        end = start + needed
        if end > len(data) or (data_size and data_size < needed):
            raise ValueError("pixel payload is truncated")
        pixels = memoryview(data)[start:end]
        if bpp == 16:
            packed = np.frombuffer(pixels, dtype="<u2").astype(np.uint32)
        elif bpp == 32:
            packed = np.frombuffer(pixels, dtype="<u4")
        else:
            raw = np.frombuffer(pixels, dtype=np.uint8).reshape(-1, 3).astype(np.uint32)
            packed = raw[:, 0] | (raw[:, 1] << 8) | (raw[:, 2] << 16)
        rgba = np.empty((height * width, 4), dtype=np.uint8)
        rgba[:, 0] = channel(packed, rmask)
        rgba[:, 1] = channel(packed, gmask)
        rgba[:, 2] = channel(packed, bmask)
        rgba[:, 3] = channel(packed, amask)
        image = Image.fromarray(rgba.reshape(height, width, 4), mode="RGBA")
        relative = path.relative_to(root).with_suffix(".png")
        destination = out / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        image.save(destination, optimize=False, compress_level=3)
        decoded.append({"source": path.relative_to(root).as_posix(), "png": destination.relative_to(out).as_posix(),
                        "width": width, "height": height, "bits_per_pixel": bpp, "bytes": len(data)})
    except Exception as error:
        failed.append({"path": path.relative_to(root).as_posix(), "error": str(error)})
report = {"decoder": "numpy-vectorized-mask-extraction-v2", "decoded": len(decoded), "failed": len(failed),
          "textures": decoded, "errors": failed}
Path("reports/pvr-decode-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"decoded": len(decoded), "failed": len(failed), "sample": decoded[:5], "errors": failed[:10]},
                 ensure_ascii=False, indent=2))
if not decoded:
    raise SystemExit("No PVR textures were decoded.")
