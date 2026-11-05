import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path

import py7zr

MODULE_PATH = Path(__file__).with_name("extract_nested_audio_7z.py")
SPEC = importlib.util.spec_from_file_location("extract_nested_audio_7z", MODULE_PATH)
EXTRACTOR = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(EXTRACTOR)


class NestedAudioExtractionTests(unittest.TestCase):
    def test_safe_member_rejects_traversal_and_absolute_paths(self):
        self.assertIsNone(EXTRACTOR.safe_member("../escape.ogg"))
        self.assertIsNone(EXTRACTOR.safe_member("/absolute/escape.ogg"))
        self.assertEqual(EXTRACTOR.safe_member("music/theme.ogg"), "music/theme.ogg")

    def test_extracts_only_audio_and_appends_provenance(self):
        with tempfile.TemporaryDirectory(prefix="clash-audio-test-") as temp:
            root = Path(temp)
            audio_root = root / "resource_stage" / "audio"
            audio_root.mkdir(parents=True)
            archive_path = audio_root / "sample.7z"
            source_audio = root / "theme.ogg"
            source_audio.write_bytes(b"verified-audio-payload")
            source_text = root / "readme.txt"
            source_text.write_text("not an audio payload", encoding="utf-8")
            with py7zr.SevenZipFile(archive_path, mode="w") as archive:
                archive.write(source_audio, arcname="music/theme.ogg")
                archive.write(source_text, arcname="music/readme.txt")
            index_path = root / "reports" / "resource-source-index.csv"
            index_path.parent.mkdir(parents=True)
            with index_path.open("w", encoding="utf-8", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=EXTRACTOR.FIELDS)
                writer.writeheader()
                writer.writerow({
                    "category": "audio",
                    "source_archive": "resource-packs-v4",
                    "source_path": "resource_stage/audio/sample.7z",
                    "staged_path": "resource_stage/audio/sample.7z",
                    "size_bytes": archive_path.stat().st_size,
                    "sha256": "0" * 64,
                })
            old = (EXTRACTOR.ROOT, EXTRACTOR.AUDIO_ROOT, EXTRACTOR.INDEX, EXTRACTOR.REPORT)
            EXTRACTOR.ROOT = root
            EXTRACTOR.AUDIO_ROOT = audio_root
            EXTRACTOR.INDEX = index_path
            EXTRACTOR.REPORT = root / "reports" / "nested-audio-extraction.json"
            try:
                EXTRACTOR.main()
            finally:
                EXTRACTOR.ROOT, EXTRACTOR.AUDIO_ROOT, EXTRACTOR.INDEX, EXTRACTOR.REPORT = old
            outputs = list((audio_root / "nested_7z").rglob("theme.ogg"))
            self.assertEqual(len(outputs), 1)
            self.assertEqual(outputs[0].read_bytes(), source_audio.read_bytes())
            rows = list(csv.DictReader(index_path.open("r", encoding="utf-8", newline="")))
            self.assertEqual(len(rows), 2)
            self.assertTrue(rows[-1]["source_path"].endswith("sample.7z!music/theme.ogg"))
            self.assertEqual(rows[-1]["category"], "audio")


if __name__ == "__main__":
    unittest.main()
