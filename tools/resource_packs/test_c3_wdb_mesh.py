import struct
import unittest

from tools.resource_packs.audit_c3_wdb import parse_mesh


def sample_mesh(magic: bytes, extended: bool = False) -> bytes:
    data = bytearray(magic + struct.pack("<I", 1))
    if extended:
        data += struct.pack("<ff", 1.0, 1.0)
    data += struct.pack("<II", 80300060, 2)
    data += struct.pack("<III4B", 803060, 803060, 0, 0, 5, 6, 0)
    data += struct.pack("<III4B", 803061, 803061, 0, 0, 5, 6, 0)
    return bytes(data)


class MeshTableTests(unittest.TestCase):
    def test_legacy_mesh_table(self):
        result = parse_mesh(sample_mesh(b"MESH"))
        self.assertEqual(result["parse_status"], "PARSED")
        self.assertEqual(result["record_count"], 1)
        self.assertEqual(result["sample_records"][0]["id"], 80300060)
        self.assertEqual(result["sample_records"][0]["part_count"], 2)
        self.assertEqual(result["sample_records"][0]["parts"][0]["mesh_id"], 803060)

    def test_extended_mobile_mesz_header(self):
        result = parse_mesh(sample_mesh(b"MESZ", extended=True))
        self.assertEqual(result["parse_status"], "PARSED")
        self.assertEqual(result["record_start_offset"], 16)
        self.assertEqual(result["header_extension_hex"], "00 00 80 3f 00 00 80 3f")

    def test_unknown_layout_is_reported_not_guessed(self):
        data = b"MESZ" + struct.pack("<I", 1) + struct.pack("<II", 0x3F800000, 0x3F800000)
        result = parse_mesh(data)
        self.assertEqual(result["parse_status"], "LAYOUT_UNRESOLVED")
        self.assertIn("header_hex", result)


if __name__ == "__main__":
    unittest.main()
