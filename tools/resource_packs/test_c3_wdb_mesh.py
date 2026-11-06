import struct
import unittest

from tools.resource_packs.audit_c3_wdb import parse_mesh, parse_ropt


def sample_mesh(magic: bytes) -> bytes:
    data = bytearray(magic + struct.pack("<I", 2))
    for unique_id, mesh_ids in ((80300060, [803060]), (80300061, [803060, 803061])):
        data += struct.pack("<II", unique_id, len(mesh_ids))
        for mesh_id in mesh_ids:
            data += struct.pack("<III4B", mesh_id, mesh_id, 0, 0, 5, 6, 0)
            if magic == b"MESZ":
                data += struct.pack("<8f", 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    return bytes(data)


class MeshTableTests(unittest.TestCase):
    def test_legacy_mesh_table(self):
        result = parse_mesh(sample_mesh(b"MESH"))
        self.assertEqual(result["parse_status"], "PARSED")
        self.assertEqual(result["record_count"], 2)
        self.assertEqual(result["sample_records"][0]["id"], 80300060)
        self.assertEqual(result["sample_records"][0]["parts"][0]["mesh_id"], 803060)
        self.assertEqual(result["sample_records"][0]["parts"][0]["part_extension_f32"], [])

    def test_mobile_mesz_extension_is_per_part(self):
        result = parse_mesh(sample_mesh(b"MESZ"))
        self.assertEqual(result["parse_status"], "PARSED")
        self.assertEqual(result["sample_records"][0]["id"], 80300060)
        self.assertEqual(result["sample_records"][1]["part_count"], 2)
        self.assertEqual(result["sample_records"][1]["parts"][0]["mesh_id"], 803060)
        self.assertEqual(result["sample_records"][1]["parts"][1]["mesh_id"], 803061)
        self.assertEqual(result["sample_records"][1]["parts"][1]["part_extension_f32"], [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0])

    def test_rejects_truncated_mesz_extension(self):
        data = b"MESZ" + struct.pack("<I", 1)
        data += struct.pack("<II", 80300060, 1)
        data += struct.pack("<III4B", 803060, 803060, 0, 0, 5, 6, 0)
        with self.assertRaises(ValueError):
            parse_mesh(data)

    def test_rejects_invalid_part_count(self):
        data = b"MESZ" + struct.pack("<I", 1)
        data += struct.pack("<II", 80300060, 1000)
        with self.assertRaises(ValueError):
            parse_mesh(data)


    def test_rolepart_ropt_layout_and_paths(self):
        header = b"ROPT" + struct.pack("<II", 1, 1)
        name = b"body" + bytes(28)
        mesh_name = b"ini/armor.dbc"
        motion_name = b"ini/3dmotion.dbc"
        mesh_ini = mesh_name + bytes(256 - len(mesh_name))
        motion_ini = motion_name + bytes(256 - len(motion_name))
        part = name + mesh_ini + motion_ini
        dummy_name = b"dummy_body"
        dummy = struct.pack("<I", 7) + dummy_name + bytes(32 - len(dummy_name))
        result = parse_ropt(header + part + dummy)
        self.assertEqual(result["parse_status"], "PARSED")
        self.assertEqual(result["record_count"], 1)
        self.assertEqual(result["dummy_record_count"], 1)
        self.assertEqual(result["parts"][0]["name"], "body")
        self.assertEqual(result["parts"][0]["mesh_ini"], "ini/armor.dbc")
        self.assertEqual(result["parts"][0]["motion_ini"], "ini/3dmotion.dbc")
        self.assertEqual(result["dummy_parts"][0], {"id": 7, "name": "dummy_body"})

    def test_rolepart_rejects_invalid_record_size(self):
        data = b"ROPT" + struct.pack("<II", 1, 0) + bytes(543)
        with self.assertRaises(ValueError):
            parse_ropt(data)


if __name__ == "__main__":
    unittest.main()
