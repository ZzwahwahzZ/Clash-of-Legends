#!/usr/bin/env python3
"""Synthetic regression tests for the independently implemented MJP decoder."""
import struct
import unittest
import zlib
from io import BytesIO
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parent))
from decode_mjp_assets import decode_mjp
from PIL import Image


def make_fixture(width=16,height=12,alpha_mode="A8"):
    image=Image.new("RGB",(width,height),(180,40,90))
    buffer=BytesIO()
    image.save(buffer,format="JPEG",quality=90)
    jpeg=buffer.getvalue()
    split=max(16,len(jpeg)//3)
    head,tail=jpeg[:split],jpeg[split:]
    compressed_head=zlib.compress(head)
    if alpha_mode=="A8":
        alpha=bytes((index*7)%256 for index in range(width*height))
    else:
        values=[index%16 for index in range(width*height)]
        alpha=bytes((values[index]|((values[index+1] if index+1<len(values) else 0)<<4))
                    for index in range(0,len(values),2))
    compressed_alpha=zlib.compress(alpha)
    data_offset=36
    block1_total=len(compressed_head)+len(tail)
    block2_offset=data_offset+block1_total
    header=b"MJP\0"+struct.pack("<8I",data_offset,block1_total,len(compressed_head),
        len(head),block2_offset,len(compressed_alpha),len(alpha),2)
    return header+compressed_head+tail+compressed_alpha


class MJPDecoderTests(unittest.TestCase):
    def test_eight_bit_alpha(self):
        image,meta=decode_mjp(make_fixture(alpha_mode="A8"))
        self.assertEqual(image.size,(16,12))
        self.assertEqual(meta["alpha_mode"],"A8")

    def test_four_bit_alpha(self):
        image,meta=decode_mjp(make_fixture(alpha_mode="A4"))
        self.assertEqual(image.size,(16,12))
        self.assertEqual(meta["alpha_mode"],"A4")

    def test_standard_jpeg_with_mjp_extension_is_sniffed(self):
        buffer = BytesIO()
        Image.new("RGB", (7, 5), (30, 120, 210)).save(buffer, format="JPEG")
        image, meta = decode_mjp(buffer.getvalue())
        self.assertEqual(image.size, (7, 5))
        self.assertEqual(meta["source_container"], "JPEG")
        self.assertEqual(meta["alpha_mode"], "NATIVE_IMAGE")

    def test_invalid_magic_is_rejected(self):
        with self.assertRaises(ValueError):
            decode_mjp(b"not-an-mjp-file")


if __name__=="__main__":
    unittest.main()
