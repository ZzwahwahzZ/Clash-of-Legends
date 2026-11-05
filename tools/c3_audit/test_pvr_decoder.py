#!/usr/bin/env python3
"""Regression tests for raw-mask and PVRTC1 PVR v2 decoding."""
import struct
import unittest

from PIL import Image
from decode_pvr_textures import decode_pvr_v2


def pvr_v2(width, height, bpp, flags, payload, masks=(0xF800, 0x07E0, 0x001F, 0)):
    header = struct.pack("<13I", 52, height, width, 0, flags, len(payload), bpp,
                         *masks, 0x21525650, 1)
    return header + payload


class PVRDecoderTests(unittest.TestCase):
    def test_rgb565_mask_texture(self):
        # Two RGB565 pixels: red then green.
        image, meta = decode_pvr_v2(pvr_v2(2, 1, 16, 0, b"\x00\xf8\xe0\x07"))
        self.assertEqual(image.size, (2, 1))
        self.assertEqual(image.getpixel((0, 0)), (255, 0, 0, 255))
        self.assertEqual(image.getpixel((1, 0)), (0, 255, 0, 255))
        self.assertEqual(meta["decoder"], "legacy-mask-16bpp")

    def test_pvrtc1_four_bpp_texture(self):
        # PVRTC1 4bpp requires at least an 8x8 footprint.
        payload = bytes(8 * 8 // 2)
        image, meta = decode_pvr_v2(pvr_v2(8, 8, 4, 0x8319, payload, (0, 0, 0, 1)))
        self.assertEqual(image.size, (8, 8))
        self.assertEqual(meta["decoder"], "texture2ddecoder-PVRTC1-4bpp")


if __name__ == "__main__":
    unittest.main()
