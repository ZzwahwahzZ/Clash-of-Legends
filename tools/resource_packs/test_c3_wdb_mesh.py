import struct
import unittest

from tools.resource_packs.audit_c3_wdb import parse_mesh


def sample_mesh(magic: bytes) -> bytes:
    data = bytearray(magic + struct.pack("<I", 1))
    data += struct.pack("<II", 80300060, 2)
    data += struct.pack("<III4B", 803060, 803060, 0, 0, 5, 6, 0)
    data += struct.pack("<III4B", 803061, 803061, 0, 0, 5, 6, 0)
    if magic == b"MESZ":
        data += struct.pack("<8f", 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    return bytes(data)


class MeshTableTests(unittest.TestCase):
    def test_legacy_mesh_table(self):
        result = parse_mesh(sample_mesh(b"MESH"))
        self.assertEqual(result["parse_status"], "PARSED")
        self.assertEqual(result["record_count"], 1)
        self.assertEqual(result["sample_records"][0]["id"], 80300060)
        self.assertEqual(result["sample_records"][0]["part_count"], 2)
        self.assertEqual(result["sample_records"][0]["parts"][0]["mesh_id"], 803060)
        self.assertEqual(result["sample_records"][0]["record_extension_f32"], [])

    def test_mobile_mesz_record_extension(self):
        result = parse_mesh(sample_mesh(b"MESZ"))
        self.assertEqual(result["parse_status"], "PARSED")
        self.assertEqual(result["sample_records"][0]["id"], 80300060)
        self.assertEqual(result["sample_records"][0]["parts"][1]["texture_id"], 803061)
        self.assertEqual(result["sample_records"][0]["record_extension_f32"], [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0])

    def test_rejects_truncated_mesz_extension(self):
        data = b"MESZ" + struct.pack("<I", 1)
        data += struct.pack("<II", 80300060, 0)
        with self.assertRaises(ValueError):
            parse_mesh(data)

    def test_rejects_invalid_part_count(self):
        data = b"MESZ" + struct.pack("<I", 1)
        data += struct.pack("<II", 80300060, 1000)
        with self.assertRaises(ValueError):
            parse_mesh(data)


if __name__ == "__main__":
    unittest.main()
