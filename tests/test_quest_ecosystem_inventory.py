from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "quest_ecosystem_inventory",
    ROOT / "tools/gameplay_source_audit/quest_ecosystem_inventory.py",
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Cannot load quest ecosystem inventory module")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class QuestEcosystemInventoryTests(unittest.TestCase):
    def test_documented_tq_key_prefix(self):
        self.assertEqual(
            MODULE.tq_key(9527)[:16],
            bytes.fromhex("ad6b4ffbddb80e0913338ff543091588"),
        )

    def test_documented_algorithm_known_answer_vector(self):
        plaintext = (
            b'local MainTask = { [0] = { ["TaskID"] = 10017, '
            b'["Goal"] = 30 } }\n'
        )
        ciphertext = bytes.fromhex(
            "c1b5c2f01bbc5db97aefdefe74641d167d76239f2ee900c8"
            "a00e991faa916656ea95212740564fe7cc3b9c3519a3061f"
            "81e97856a9984f9a88a00404e0914d3381"
        )
        self.assertEqual(MODULE.decrypt_tq(ciphertext, 9527), plaintext)

    def test_high_binary_bytes_are_not_counted_as_printable_text(self):
        probe = MODULE.text_probe(bytes(range(128, 256)) * 20)
        self.assertFalse(probe["text_candidate"])
        self.assertEqual(probe["lua_markers"], [])

    def test_quest_world_related_paths_are_discovered(self):
        paths = (
            "assets/ConquerRes/ini/luacfg/questinfo.dat",
            "assets/ConquerRes/ini/npc.ini",
            "assets/ConquerRes/ini/gamemap.dat",
            "assets/ConquerRes/ini/itemtype/itemtype13.ini",
            "assets/ConquerRes/script/clienttask1001.dat",
            "assets/ConquerRes/data/client_realm_task/juqing01.dat",
        )
        for path in paths:
            with self.subTest(path=path):
                self.assertTrue(MODULE.is_interesting(path))

    def test_other_asset_and_non_game_paths_are_not_discovered(self):
        self.assertFalse(MODULE.is_interesting("assets/ConquerRes/texture/sky.dds"))
        self.assertFalse(MODULE.is_interesting("res/drawable/icon.png"))

    def test_task_id_and_duplicate_detection(self):
        source = (
            b'local MainTask = {\n'
            b' [0] = { ["TaskID"] = 10017, ["NpcID"] = 501, ["MapID"] = 1000 },\n'
            b' [1] = { ["TaskID"] = 10017, ["Goal"] = 30 },\n'
            b'}\n'
        )
        parsed = MODULE.parse_ascii_ids(source)
        self.assertEqual(parsed["task_id_count"], 2)
        self.assertEqual(parsed["duplicate_task_ids"], [10017])
        self.assertEqual(parsed["field_values"]["NpcID"], [501])
        self.assertEqual(parsed["field_values"]["MapID"], [1000])


if __name__ == "__main__":
    unittest.main()
