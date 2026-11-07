from __future__ import annotations

import importlib.util
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "tools/gameplay_source_audit/mobile_apk_reader_probe.py"
SPEC = importlib.util.spec_from_file_location("mobile_apk_reader_probe", PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Cannot load mobile APK reader probe")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def encode_uleb128(value: int) -> bytes:
    out = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return bytes(out)


def synthetic_dex(strings: list[str]) -> bytes:
    header = bytearray(0x70)
    header[:8] = b"dex\n035\x00"
    string_table = 0x70
    struct.pack_into("<I", header, 0x38, len(strings))
    struct.pack_into("<I", header, 0x3C, string_table)
    data = bytearray(header)
    data.extend(b"\x00" * (4 * len(strings)))
    for index, value in enumerate(strings):
        raw = value.encode("utf-8")
        offset = len(data)
        struct.pack_into("<I", data, string_table + index * 4, offset)
        data.extend(encode_uleb128(len(value)))
        data.extend(raw)
        data.append(0)
    return bytes(data)


class MobileApkReaderProbeTests(unittest.TestCase):
    def test_reads_dex_string_table_and_finds_resource_tokens(self):
        dex = synthetic_dex(["questinfo.dat", "com.example.Loader", "TaskID"])
        strings = MODULE.decode_dex_strings(dex)
        self.assertEqual(strings, ["questinfo.dat", "com.example.Loader", "TaskID"])
        matches = MODULE.matching_strings(strings)
        self.assertEqual([item["value"] for item in matches], ["questinfo.dat", "TaskID"])

    def test_decodes_uleb128(self):
        encoded = encode_uleb128(624485)
        value, offset = MODULE.read_uleb128(encoded, 0)
        self.assertEqual(value, 624485)
        self.assertEqual(offset, len(encoded))

    def test_rejects_non_dex_input(self):
        with self.assertRaises(ValueError):
            MODULE.decode_dex_strings(b"not a dex file")

    def test_rejects_truncated_uleb128(self):
        with self.assertRaises(ValueError):
            MODULE.read_uleb128(b"\x80", 0)


if __name__ == "__main__":
    unittest.main()
