import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


class MobileApkInventoryTests(unittest.TestCase):
    def test_nested_apk_dex_and_arm64_library_are_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            apk = root / "sample.apk"
            dex = b"dex\n035\0" + b"AssetManager Cipher getInstance TPI C3 decrypt"
            elf = bytearray(64)
            elf[:4] = b"\x7fELF"
            elf[4] = 2
            elf[5] = 1
            struct.pack_into("<H", elf, 18, 183)
            with zipfile.ZipFile(apk, "w") as z:
                z.writestr("classes.dex", dex)
                z.writestr("lib/arm64-v8a/libgame.so", bytes(elf) + b" C3 MJP PVR decrypt")
                z.writestr("assets/ConquerRes/data.tpi", b"TPI")
            source = root / "source.zip"
            with zipfile.ZipFile(source, "w") as z:
                z.write(apk, "ConquerOnline/install_time_1001.apk")
            out = root / "out"
            # Exercise the public CLI path to cover nested APK extraction and JSON serialization.
            import subprocess, sys
            subprocess.run(
                [sys.executable, str(ROOT / "tools/asset_forensics/inspect_mobile_apks.py"),
                 str(source), "--out", str(out)],
                check=True, capture_output=True, text=True,
            )
            data = json.loads((out / "mobile-apk-static-analysis.json").read_text())
            self.assertEqual(data["apk_count"], 1)
            self.assertEqual(data["dex_count"], 1)
            self.assertEqual(data["native_library_count"], 1)
            self.assertEqual(data["native_analysis"][0]["arch"], "AArch64")
            self.assertIn("TPI", data["dex_analysis"][0]["clue_strings"][0] + " " + " ".join(data["dex_analysis"][0]["clue_strings"]))

if __name__ == "__main__":
    unittest.main()
