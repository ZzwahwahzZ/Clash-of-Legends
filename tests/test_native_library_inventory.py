import io
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.asset_forensics.inspect_native_libraries import inspect


def fake_elf(machine: int = 183) -> bytes:
    data = bytearray(64)
    data[:4] = b"\x7fELF"
    data[4], data[5], data[6] = 2, 1, 1
    data[18:20] = int(machine).to_bytes(2, "little")
    return bytes(data)


class NativeLibraryInventoryTests(unittest.TestCase):
    def test_nested_apk_extracts_arm64_library(self):
        with tempfile.TemporaryDirectory() as temp:
            root, output = Path(temp) / "root", Path(temp) / "out"
            root.mkdir()
            apk = io.BytesIO()
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("lib/arm64-v8a/libCQ2Client.so", fake_elf())
            with zipfile.ZipFile(root / "source.zip", "w") as archive:
                archive.writestr("nested/game.apk", apk.getvalue())
            report = inspect(root, output)
            self.assertEqual(report["status"], "FOUND")
            self.assertEqual(report["architecture_counts"], {"arm64-v8a/AArch64": 1})
            self.assertEqual(len(list(output.glob("*.so"))), 1)

    def test_standalone_library_and_path_traversal_rejection(self):
        with tempfile.TemporaryDirectory() as temp:
            root, output = Path(temp) / "root", Path(temp) / "out"
            root.mkdir()
            (root / "libCQ2Client.so").write_bytes(fake_elf(183))
            apk = io.BytesIO()
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("../escape/libbad.so", fake_elf())
                archive.writestr("lib/armeabi-v7a/libgood.so", fake_elf(40))
            (root / "client.apk").write_bytes(apk.getvalue())
            report = inspect(root, output)
            self.assertEqual(report["unique_libraries_extracted"], 2)
            self.assertFalse((Path(temp) / "escape" / "libbad.so").exists())

    def test_no_library_is_explicit_not_found(self):
        with tempfile.TemporaryDirectory() as temp:
            root, output = Path(temp) / "root", Path(temp) / "out"
            root.mkdir()
            report = inspect(root, output)
            self.assertEqual(report["status"], "NOT_FOUND")
            self.assertTrue((output / "native-library-inventory.json").is_file())


if __name__ == "__main__":
    unittest.main()
