#!/usr/bin/env python3
"""Decode legacy PVR v2 raw-mask and PVRTC1 textures into Godot-ready PNG."""
from __future__ import annotations
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image

try:
    import texture2ddecoder
except ImportError:
    texture2ddecoder = None


def channel(values: np.ndarray, mask: int) -> np.ndarray:
    if mask == 0:
        return np.full(values.shape, 255, dtype=np.uint8)
    shift = (mask & -mask).bit_length() - 1
    bits = mask.bit_count()
    maximum = (1 << bits) - 1
    raw = (values & np.uint32(mask)) >> np.uint32(shift)
    scaled = (raw.astype(np.uint64) * 255 + maximum // 2) // maximum
    return scaled.astype(np.uint8)


def decode_pvr_v2(data: bytes):
    if len(data) < 52 or data[44:48] != b"PVR!":
        raise ValueError("unsupported PVR header")
    header_size, height, width, mips, flags, data_size, bpp, rmask, gmask, bmask, amask, magic, surfaces = struct.unpack_from("<13I", data, 0)
    if header_size < 52 or header_size > len(data) or width < 1 or height < 1 or surfaces != 1:
        raise ValueError("invalid dimensions, header size, or surface count")
    payload = data[header_size:]
    if data_size and data_size > len(payload):
        raise ValueError("declared PVR payload is truncated")

    # Legacy PVR v2 encodes PVRTC1 4bpp as pixel-format flag 0x0D
    # (MGLPT_PVRTC4) or 0x19 (OGL_PVRTC4). These are block-compressed,
    # not 4-bit channel masks. Decode only the top mip for runtime PNG;
    # the remaining mip chain is intentionally not copied into the PNG.
    pixel_format = flags & 0xFF
    if bpp == 4 or pixel_format in (0x0D, 0x19):
        if pixel_format not in (0x0D, 0x19):
            raise ValueError(f"unsupported 4bpp PVR pixel format flag 0x{pixel_format:02x}")
        if texture2ddecoder is None:
            raise RuntimeError("PVRTC1 decoder missing: install texture2ddecoder==1.0.6")
        base_bytes = max(width, 8) * max(height, 8) // 2
        if len(payload) < base_bytes:
            raise ValueError(f"PVRTC4 base mip truncated: {len(payload)} < {base_bytes}")
        bgra = texture2ddecoder.decode_pvrtc(payload[:base_bytes], width, height, False)
        if len(bgra) != width * height * 4:
            raise ValueError(f"PVRTC4 decoder returned {len(bgra)} bytes, expected {width * height * 4}")
        image = Image.frombytes("RGBA", (width, height), bgra, "raw", ("BGRA"))
        return image, {"pixel_format": pixel_format, "decoder": "texture2ddecoder-PVRTC1-4bpp",
                       "mipmaps_in_source": mips, "decoded_mip": 0}

    if bpp not in (16, 24, 32):
        raise ValueError(f"unsupported raw pixel depth {bpp}")
    bytes_per_pixel = bpp // 8
    needed = width * height * bytes_per_pixel
    if len(payload) < needed or (data_size and data_size < needed):
        raise ValueError("pixel payload is truncated")
    pixels = memoryview(payload)[:needed]
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
    return Image.fromarray(rgba.reshape(height, width, 4), mode="RGBA"), {
        "pixel_format": pixel_format, "decoder": f"legacy-mask-{bpp}bpp",
        "mipmaps_in_source": mips, "decoded_mip": 0
    }


def main():
    decoded = []
    failed = []
    root = Path("build/pvr-source")
    out = Path("build/pvr-png")
    for path in sorted(root.rglob("*.pvr")):
        try:
            image, metadata = decode_pvr_v2(path.read_bytes())
            relative = path.relative_to(root).with_suffix(".png")
            destination = out / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            image.save(destination, optimize=False, compress_level=3)
            decoded.append({"source": path.relative_to(root).as_posix(),
                            "png": destination.relative_to(out).as_posix(),
                            "width": image.width, "height": image.height,
                            "bytes": path.stat().st_size, **metadata})
        except Exception as error:
            failed.append({"path": path.relative_to(root).as_posix(), "error": str(error)})
    report = {"decoder": "legacy-PVRv2-mask-plus-PVRTC1", "decoded": len(decoded),
              "failed": len(failed), "textures": decoded, "errors": failed}
    Path("reports/pvr-decode-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"decoded": len(decoded), "failed": len(failed),
                      "pvrtc": sum(1 for row in decoded if "PVRTC" in row["decoder"]),
                      "sample": decoded[:5], "errors": failed[:10]},
                     ensure_ascii=False, indent=2))
    if not decoded:
        raise SystemExit("No PVR textures were decoded.")
    if failed:
        raise SystemExit(f"{len(failed)} PVR textures failed decoding; refusing incomplete texture coverage.")


if __name__ == "__main__":
    main()
