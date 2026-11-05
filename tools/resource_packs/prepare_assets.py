#!/usr/bin/env python3
"""Build category staging trees from verified bundles and embedded Android APK assets."""
import csv, hashlib, json, re, shutil, tempfile, zipfile
from pathlib import Path

ROOT = Path.cwd()
STAGE = ROOT / "resource_stage"
SOURCE = ROOT / "build/source_archives"
REPORTS = ROOT / "reports"
shutil.rmtree(STAGE, ignore_errors=True)
STAGE.mkdir(parents=True, exist_ok=True)
REPORTS.mkdir(parents=True, exist_ok=True)
if not SOURCE.is_dir():
    raise SystemExit(f"Source archive directory does not exist: {SOURCE}")

ARCHIVES = [
    "extracted-assets-001.zip",
    "conquer-mobile-prepared-assets.zip",
    "conquer-mobile-supplemental-assets.zip",
]
EXTS = {
    ".glb", ".gltf", ".obj", ".fbx", ".dae", ".blend",
    ".tscn", ".tres", ".res", ".scn",
    ".png", ".jpg", ".jpeg", ".webp", ".tga", ".bmp",
    ".ktx", ".ktx2", ".dds", ".pvr", ".astc",
    ".ogg", ".wav", ".mp3", ".flac",
    ".ttf", ".otf", ".fnt",
    ".json", ".material", ".shader", ".gdshader", ".cfg", ".xml", ".ini",
    ".bin", ".dat", ".pak", ".atlas", ".plist",
    ".c3b", ".c3t", ".c3a", ".c3i", ".c3e", ".c3s", ".c3m", ".c3d", ".c3p",
    ".skel", ".skeleton", ".anim", ".ani", ".mesh", ".model",
    ".scene", ".tme", ".pul", ".pux", ".otherdata", ".fui", ".rgn",
    ".tpd", ".tpi", ".wdb", ".fcs", ".dmap", ".map", ".terrain", ".bytes", ".7z",
}
RULES = [
    ("audio", re.compile(r"audio|sound|music|voice|(^|[/_.-])sfx([/_.-]|$)|\.ogg$|\.wav$|\.mp3$|\.flac$", re.I)),
    ("interface", re.compile(r"fgui|interface|ui/|layout|font|sprite|icon|\.fui$|\.rgn$", re.I)),
    ("maps", re.compile(r"map|terrain|scene|world|city|village|dungeon|height|\.dmap$|\.pul$|\.pux$|\.otherdata$", re.I)),
    ("characters", re.compile(r"character|player|role|human|body|hair|face|skeleton|(^|[/_.-])hero([/_.-]|$)", re.I)),
    ("equipment", re.compile(r"weapon|armor|armour|equip|sword|bow|dagger|staff|shield|helmet|boot|glove|garment|ring|necklace|(^|/)item(/|$)", re.I)),
    ("mounts", re.compile(r"mount|horse|pet|ride|dragon", re.I)),
    ("effects", re.compile(r"effect|particle|skill|spell|magic|vfx|terrainmagic|(^|[/_.-])fx([/_.-]|$)|trail|projectile|\.tme$", re.I)),
    ("animations", re.compile(r"(^|/)ani(/|$)|animation|\.ani$", re.I)),
    ("monsters", re.compile(r"monster|(^|[/_.-])mob([/_.-]|$)|creature|beast|boss|npc_enemy", re.I)),
]
seen = set()
rows = []
totals = {}
extension_counts = {}
archive_entry_counts = {}
apk_inner_entry_counts = {}
nested_zip_entry_counts = {}
nested_7z_entry_counts = {}
unsupported = []

def note_extension(ext):
    extension_counts[ext] = extension_counts.get(ext, 0) + 1

def classify(path, ext):
    for category, pattern in RULES:
        if pattern.search(path):
            return category
    if ext in {".ogg", ".wav", ".mp3", ".flac"}:
        return "audio"
    return "world"

def safe_relative(value):
    parts = [part for part in value.replace("\\", "/").split("/") if part not in ("", ".", "..")]
    clean = "/".join(parts)
    return re.sub(r"[^A-Za-z0-9._/-]+", "_", clean).lstrip("/")

def stage_stream(source_archive, source_path, staged_hint, size, opener):
    ext = Path(source_path).suffix.lower() or "[no-extension]"
    note_extension(ext)
    if ext not in EXTS:
        unsupported.append({"archive": source_archive, "path": source_path, "extension": ext, "size_bytes": size})
        return
    if any(part.startswith(".") for part in source_path.replace("\\", "/").split("/")):
        return
    digest = hashlib.sha256()
    with opener() as stream:
        while True:
            block = stream.read(1024 * 1024)
            if not block:
                break
            digest.update(block)
    sha = digest.hexdigest()
    if sha in seen:
        return
    seen.add(sha)
    category = classify(source_path, ext)
    safe = safe_relative(staged_hint)
    destination = STAGE / category / safe
    destination.parent.mkdir(parents=True, exist_ok=True)
    with opener() as stream, open(destination, "wb") as output:
        shutil.copyfileobj(stream, output, 1024 * 1024)
    rows.append({
        "category": category,
        "source_archive": source_archive,
        "source_path": source_path,
        "staged_path": destination.relative_to(ROOT).as_posix(),
        "size_bytes": size,
        "sha256": sha,
    })
    totals[category] = totals.get(category, 0) + 1

def scan_nested_zip(source_archive, outer_path, outer_stream, depth=1):
    if depth > 2:
        return
    with tempfile.NamedTemporaryFile(suffix=".zip") as temp:
        shutil.copyfileobj(outer_stream, temp, 1024 * 1024)
        temp.flush()
        try:
            with zipfile.ZipFile(temp.name) as nested:
                for item in nested.infolist():
                    if item.is_dir():
                        continue
                    nested_zip_entry_counts[source_archive] = nested_zip_entry_counts.get(source_archive, 0) + 1
                    raw_inner = item.filename.replace("\\", "/")
                    if not raw_inner or raw_inner.startswith("../"):
                        continue
                    ext = Path(raw_inner).suffix.lower()
                    if ext == ".zip":
                        with nested.open(item) as inner_stream:
                            scan_nested_zip(source_archive, outer_path + "!" + raw_inner, inner_stream, depth + 1)
                    else:
                        staged = "nested_archives/" + Path(outer_path).stem + "/" + raw_inner
                        stage_stream(source_archive, outer_path + "!" + raw_inner, staged, item.file_size, lambda n=nested, i=item: n.open(i))
        except zipfile.BadZipFile:
            unsupported.append({"archive": source_archive, "path": outer_path, "extension": ".zip-invalid", "size_bytes": 0})

def scan_apk(source_archive, outer_path, outer_stream):
    with tempfile.NamedTemporaryFile(suffix=".apk") as temp:
        shutil.copyfileobj(outer_stream, temp, 1024 * 1024)
        temp.flush()
        try:
            with zipfile.ZipFile(temp.name) as apk:
                for item in apk.infolist():
                    if item.is_dir():
                        continue
                    apk_inner_entry_counts[source_archive] = apk_inner_entry_counts.get(source_archive, 0) + 1
                    inner = item.filename.replace("\\", "/")
                    if not (inner.startswith("assets/") or inner.startswith("res/raw/") or inner.startswith("res/drawable")):
                        continue
                    ext = Path(inner).suffix.lower()
                    if ext == ".zip":
                        with apk.open(item) as nested_stream:
                            scan_nested_zip(source_archive, outer_path + "!" + inner, nested_stream)
                        continue
                    if ext == ".7z":
                        with apk.open(item) as archive_stream:
                            scan_nested_7z(source_archive, outer_path + "!" + inner, archive_stream)
                        staged = "apk_assets/" + Path(outer_path).stem + "/" + inner
                        stage_stream(source_archive, outer_path + "!" + inner, staged, item.file_size, lambda a=apk, i=item: a.open(i))
                        continue
                    staged = "apk_assets/" + Path(outer_path).stem + "/" + inner
                    stage_stream(source_archive, outer_path + "!" + inner, staged, item.file_size, lambda a=apk, i=item: a.open(i))
        except zipfile.BadZipFile:
            unsupported.append({"archive": source_archive, "path": outer_path, "extension": ".apk-invalid", "size_bytes": 0})

def scan_nested_7z(source_archive, outer_path, outer_stream):
    try:
        import py7zr
    except ImportError:
        unsupported.append({"archive": source_archive, "path": outer_path, "extension": ".7z-no-extractor", "size_bytes": 0})
        return
    with tempfile.NamedTemporaryFile(suffix=".7z") as temp:
        shutil.copyfileobj(outer_stream, temp, 1024 * 1024)
        temp.flush()
        with tempfile.TemporaryDirectory() as destination:
            try:
                with py7zr.SevenZipFile(temp.name, mode="r") as archive:
                    safe_names = []
                    for name in archive.getnames():
                        normalized = name.replace("\\", "/")
                        parts = [part for part in normalized.split("/") if part not in ("", ".")]
                        if not normalized.startswith("/") and ".." not in parts:
                            safe_names.append(name)
                    if safe_names:
                        archive.extract(path=destination, targets=safe_names)
                root = Path(destination)
                for file_path in root.rglob("*"):
                    if not file_path.is_file():
                        continue
                    relative = file_path.relative_to(root).as_posix()
                    nested_7z_entry_counts[source_archive] = nested_7z_entry_counts.get(source_archive, 0) + 1
                    staged = "nested_7z/" + Path(outer_path).stem + "/" + relative
                    stage_stream(source_archive, outer_path + "!" + relative, staged, file_path.stat().st_size, lambda path=file_path: open(path, "rb"))
            except Exception as error:
                unsupported.append({"archive": source_archive, "path": outer_path, "extension": ".7z-extract-error", "size_bytes": 0, "error": str(error)[:240]})

for archive_name in ARCHIVES:
    archive = SOURCE / archive_name
    if not archive.exists():
        raise SystemExit(f"Missing downloaded archive: {archive}")
    with zipfile.ZipFile(archive) as outer:
        for info in outer.infolist():
            if info.is_dir():
                continue
            raw = info.filename.replace("\\", "/")
            archive_entry_counts[archive_name] = archive_entry_counts.get(archive_name, 0) + 1
            ext = Path(raw).suffix.lower()
            if ext == ".apk":
                with outer.open(info) as apk_stream:
                    scan_apk(archive_name, raw, apk_stream)
            elif ext == ".zip":
                with outer.open(info) as nested_stream:
                    scan_nested_zip(archive_name, raw, nested_stream)
            else:
                stage_stream(archive_name, raw, raw, info.file_size, lambda z=outer, i=info: z.open(i))

with open(REPORTS / "resource-source-index.csv", "w", newline="", encoding="utf-8") as file:
    writer = csv.DictWriter(file, fieldnames=["category", "source_archive", "source_path", "staged_path", "size_bytes", "sha256"])
    writer.writeheader()
    writer.writerows(rows)

audit = {
    "archive_entry_counts": archive_entry_counts,
    "apk_inner_entry_counts": apk_inner_entry_counts,
    "nested_zip_entry_counts": nested_zip_entry_counts,
    "nested_7z_entry_counts": nested_7z_entry_counts,
    "extension_counts": dict(sorted(extension_counts.items())),
    "unsupported_files": unsupported,
    "unique_supported_files": len(rows),
    "category_counts": totals,
    "staged_bytes": sum(row["size_bytes"] for row in rows),
}
(REPORTS / "source-archive-extension-audit.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(audit, ensure_ascii=False, indent=2))
if not rows:
    raise SystemExit("No compatible asset files found; refusing to publish empty packs.")
