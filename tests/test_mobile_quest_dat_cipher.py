from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, relative_path: str):
    path = ROOT / relative_path
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load module: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


archive_decoder = load_module(
    "mobile_quest_source_decoder",
    "tools/gameplay_source_audit/mobile_quest_source_decoder.py",
)
standalone_decoder = load_module(
    "decode_mobile_quest_dat",
    "tools/resource_packs/decode_mobile_quest_dat.py",
)


class TQFileCipherKnownAnswerTests(unittest.TestCase):
    # Algorithm-level known-answer vector from the published TQ cipher description.
    # This is not a ciphertext sample from the target mobile APK.
    def test_seed_9527_key_prefix(self):
        expected = bytes.fromhex("ad6b4ffbddb80e0913338ff543091588")
        self.assertEqual(archive_decoder.key_for(9527)[:16], expected)
        self.assertEqual(standalone_decoder.make_key(9527)[:16], expected)

    def test_both_decoders_match_known_ciphertext(self):
        plaintext = (
            b'local MainTask = { [0] = { ["TaskID"] = 10017, '
            b'["Goal"] = 30 } }\n'
        )
        ciphertext = bytes.fromhex(
            "c1b5c2f01bbc5db97aefdefe74641d167d76239f2ee900c8"
            "a00e991faa916656ea95212740564fe7cc3b9c3519a3061f"
            "81e97856a9984f9a88a00404e0914d3381"
        )
        self.assertEqual(archive_decoder.decrypt_tq(ciphertext, 9527), plaintext)
        self.assertEqual(standalone_decoder.decrypt_tq(ciphertext, 9527), plaintext)

    def test_encrypt_is_inverse_for_both_supported_seeds(self):
        sample = b"quest-table-round-trip"
        for seed in (9527, 1234):
            encrypted = standalone_decoder.encrypt_tq(sample, seed)
            self.assertEqual(standalone_decoder.decrypt_tq(encrypted, seed), sample)
            self.assertEqual(archive_decoder.decrypt_tq(encrypted, seed), sample)


if __name__ == "__main__":
    unittest.main()
