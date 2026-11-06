import struct, tempfile, unittest
from pathlib import Path
from tools.asset_forensics.decode_mobile_pvr import PVR3_MAGIC, decode_pvr, run

class MobilePvrDecoderTests(unittest.TestCase):
    def test_pvr3_uncompressed_rgba(self):
        width=2; height=1
        header=bytearray(52)
        struct.pack_into("<I",header,0,PVR3_MAGIC)
        # Pixel format 'rgba', 8 bits per channel.
        struct.pack_into("<II",header,8,int.from_bytes(b"rgba","little"),int.from_bytes(bytes((8,8,8,8)),"little"))
        struct.pack_into("<II",header,24,height,width)
        struct.pack_into("<I",header,48,0)
        payload=bytes((255,0,0,255,0,255,0,128))
        w,h,rgba,fmt=decode_pvr(bytes(header)+payload)
        self.assertEqual((w,h),(2,1))
        self.assertEqual(rgba,payload)
        self.assertEqual(fmt,"PVR3_uncompressed")

    def test_pvr2_rgba8888_header(self):
        header=bytearray(52)
        # PVR v2: header, height, width, mipmaps, flags, dataSize, bpp, masks, magic.
        struct.pack_into("<12I",header,0,52,1,1,0,0x12,4,32,0x000000ff,0x0000ff00,0x00ff0000,0xff000000,0x21525650)
        w,h,rgba,fmt=decode_pvr(bytes(header)+bytes((255,0,0,255)))
        self.assertEqual((w,h),(1,1))
        self.assertEqual(rgba,bytes((255,0,0,255)))
        self.assertEqual(fmt,"PVR2_32bpp_fmt_12")

    def test_invalid_magic_rejected(self):
        with self.assertRaises(ValueError): decode_pvr(b"X"*64)

if __name__=="__main__":
    unittest.main()
