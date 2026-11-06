import tempfile
import unittest
from pathlib import Path

from tools.asset_forensics.inspect_fui_headers import inspect


class FuiHeaderTests(unittest.TestCase):
    def test_identifies_v7_only_by_magic_and_version(self):
        with tempfile.TemporaryDirectory() as temp:
            root, output = Path(temp) / "root", Path(temp) / "out"
            root.mkdir()
            (root / "valid.fui").write_bytes(b"FGUI" + (7).to_bytes(4, "little") + b"\x01" + b"\x00" * 40)
            (root / "legacy.fui").write_bytes(b"FGUI" + (3).to_bytes(4, "little") + b"\x00" + b"\x00" * 40)
            (root / "unknown.fui").write_bytes(b"NOTFUI" + b"\x00" * 40)
            report = inspect(root, output)
            self.assertEqual(report["fairygui_v7_candidates"], 1)
            self.assertEqual(report["other_fairygui_versions"], 1)
            self.assertEqual(report["unknown_fui_formats"], 1)

    def test_empty_directory_reports_no_candidate(self):
        with tempfile.TemporaryDirectory() as temp:
            root, output = Path(temp) / "root", Path(temp) / "out"
            root.mkdir()
            report = inspect(root, output)
            self.assertEqual(report["file_count"], 0)
            self.assertTrue((output / "fui-header-inventory.json").is_file())


if __name__ == "__main__":
    unittest.main()
