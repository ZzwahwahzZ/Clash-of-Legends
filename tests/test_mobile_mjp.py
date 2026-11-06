import io
import struct
import tempfile
import unittest
import zlib
from pathlib import Path
from PIL import Image

from tools.asset_forensics.decode_mobile_mjp import decode_file


def raw_deflate(data):
    compressor = zlib.compressobj(level=9, wbits=-15)
    return compressor.compress(data) + compressor.flush()


class MobileMjpDecoderTests(unittest.TestCase):
    def test_decodes_jpeg_and_preserves_eight_bit_alpha(self):
        image = Image.new("RGB", (4, 2), (180, 70, 30))
        stream = io.BytesIO()
        image.save(stream, format="JPEG", quality=95)
        jpeg = stream.getvalue()
        split = max(16, len(jpeg) // 2)
        head, tail = jpeg[:split], jpeg[split:]
        compressed_head = raw_deflate(head)
        alpha = bytes([0, 32, 64, 96, 128, 160, 192, 255])
        compressed_alpha = raw_deflate(alpha)
        data_offset = 36
        block1_total = len(compressed_head) + len(tail)
        block2_offset = data_offset + block1_total
        header = struct.pack(
            "<8I", data_offset, block1_total, len(compressed_head), len(head),
            block2_offset, len(compressed_alpha), len(alpha), 2
        )
        payload = b"MJP\0" + header + compressed_head + tail + compressed_alpha

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "sample.mjp"
            target = root / "sample.png"
            source.write_bytes(payload)
            report = decode_file(source, target)
            self.assertEqual((report["width"], report["height"]), (4, 2))
            self.assertEqual(report["alpha_mode"], "8-bit")
            with Image.open(target) as result:
                self.assertEqual(result.mode, "RGBA")
                self.assertEqual(list(result.getchannel("A").getdata()), list(alpha))

if __name__ == "__main__":
    unittest.main()
