from pathlib import Path
from urllib.parse import urljoin, urlparse, unquote
from bs4 import BeautifulSoup
from PIL import Image
from zipfile import ZipFile, ZIP_DEFLATED
import requests, hashlib, csv, json, re, time

ROOT = Path("conquer_original_reference_images")
ROOT.mkdir(parents=True, exist_ok=True)
ZIP_PATH = Path("conquer_original_reference_images.zip")
SOURCE_PAGES = {
    "characters": ["https://comobile.99.com/guide/info/classes/2023-01-31/classes_-_classes_introduction.shtml"],
    "maps": ["https://comobile.99.com/guide/info/maps/2023-02-17/guide_-_maps.shtml"],
    "mounts": ["https://comobile.99.com/guide/info/classes/2023-02-14/status_-_mount_system.shtml"],
    "equipment": ["https://comobile.99.com/guide/info/equipment/2023-02-15/equipment_-_equipment_type.shtml"],
    "monsters": ["https://co.99.com/downloads/wallpapers_monster.shtml"],
}
ALLOWED_HOSTS = {"comobile.99.com", "co.99.com", "hw.99.com", "images.99.com"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
MIN_BYTES, MAX_BYTES, MAX_PER_CATEGORY = 5000, 30_000_000, 500
session = requests.Session()
session.headers["User-Agent"] = "Mozilla/5.0 (compatible; ClashOfLegendsReferenceCollector/1.0)"
manifest, page_report, seen_hashes, seen_urls = [], [], set(), set()

def allowed(url):
    p = urlparse(url)
    return p.scheme in ("http", "https") and (p.hostname or "").lower() in ALLOWED_HOSTS

def image_urls(html, page_url):
    soup = BeautifulSoup(html, "html.parser")
    found = []
    for tag in soup.find_all(["img", "a", "source"]):
        for attr in ("src", "data-src", "data-original", "data-lazy-src", "href"):
            raw = tag.get(attr)
            if raw:
                full = urljoin(page_url, raw.strip().replace("&amp;", "&"))
                if allowed(full) and Path(urlparse(full).path).suffix.lower() in IMAGE_EXTS:
                    found.append(full)
        srcset = tag.get("srcset") or tag.get("data-srcset")
        if srcset:
            for part in srcset.split(","):
                raw = part.strip().split()[0] if part.strip() else ""
                full = urljoin(page_url, raw)
                if raw and allowed(full) and Path(urlparse(full).path).suffix.lower() in IMAGE_EXTS:
                    found.append(full)
    for raw in re.findall(r"url\([\"']?([^\)\"']+)", html, flags=re.I):
        full = urljoin(page_url, raw.strip())
        if allowed(full) and Path(urlparse(full).path).suffix.lower() in IMAGE_EXTS:
            found.append(full)
    return list(dict.fromkeys(found))

def related_class_pages(html, page_url):
    soup = BeautifulSoup(html, "html.parser")
    out = []
    for a in soup.find_all("a", href=True):
        full = urljoin(page_url, a["href"])
        if allowed(full) and "/guide/info/classes/" in urlparse(full).path.lower() and full not in out:
            out.append(full)
    return out[:40]

def safe_name(url, category, index):
    base = unquote(Path(urlparse(url).path).name) or f"image_{index}.jpg"
    base = re.sub(r"[^A-Za-z0-9._-]+", "_", base)[:100]
    if Path(base).suffix.lower() not in IMAGE_EXTS:
        base += ".jpg"
    return f"{category}_{index:04d}_{base}"

for category, pages in SOURCE_PAGES.items():
    out_dir = ROOT / category
    out_dir.mkdir(parents=True, exist_ok=True)
    candidates = []
    for page in pages:
        try:
            response = session.get(page, timeout=35)
            response.raise_for_status()
            response.encoding = response.apparent_encoding or response.encoding
            html = response.text
            candidates.extend(image_urls(html, page))
            page_report.append({"category": category, "url": page, "status": "read"})
            if category == "characters":
                for related in related_class_pages(html, page):
                    try:
                        rr = session.get(related, timeout=35)
                        rr.raise_for_status()
                        rr.encoding = rr.apparent_encoding or rr.encoding
                        found = image_urls(rr.text, related)
                        candidates.extend(found)
                        page_report.append({"category": category, "url": related, "status": "read_related", "image_candidates": len(found)})
                    except Exception as exc:
                        page_report.append({"category": category, "url": related, "status": "failed", "error": str(exc)[:250]})
        except Exception as exc:
            page_report.append({"category": category, "url": page, "status": "failed", "error": str(exc)[:250]})
    saved = 0
    for url in dict.fromkeys(candidates):
        if url in seen_urls or saved >= MAX_PER_CATEGORY:
            continue
        seen_urls.add(url)
        try:
            r = session.get(url, timeout=45)
            r.raise_for_status()
            data = r.content
            if not MIN_BYTES <= len(data) <= MAX_BYTES:
                continue
            digest = hashlib.sha256(data).hexdigest()
            if digest in seen_hashes:
                continue
            dest = out_dir / safe_name(url, category, saved + 1)
            dest.write_bytes(data)
            try:
                with Image.open(dest) as im:
                    im.verify()
                with Image.open(dest) as im:
                    width, height, fmt = im.width, im.height, im.format
            except Exception:
                dest.unlink(missing_ok=True)
                continue
            seen_hashes.add(digest)
            manifest.append({"category": category, "file": str(dest.relative_to(ROOT)), "bytes": len(data),
                             "width": width, "height": height, "format": fmt, "sha256": digest, "source_url": url})
            saved += 1
            time.sleep(0.1)
        except Exception as exc:
            print(f"[SKIP] {url}: {str(exc)[:160]}")
    print(f"{category}: {saved} validated image(s)")

with (ROOT / "sources_manifest.csv").open("w", newline="", encoding="utf-8-sig") as f:
    fields = ["category", "file", "bytes", "width", "height", "format", "sha256", "source_url"]
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    writer.writerows(manifest)

summary = {
    "total_valid_images": len(manifest),
    "categories": {name: sum(1 for row in manifest if row["category"] == name) for name in SOURCE_PAGES},
    "total_image_bytes": sum(row["bytes"] for row in manifest),
    "pages": page_report,
    "source_pages": SOURCE_PAGES,
    "note": "Publicly accessible guide/gallery images only; not extracted game-client assets."
}
(ROOT / "collection_report.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
if not manifest:
    raise SystemExit("No valid images collected; ZIP not created. Inspect collection_report.json.")
with ZipFile(ZIP_PATH, "w", ZIP_DEFLATED, compresslevel=6) as archive:
    for p in ROOT.rglob("*"):
        if p.is_file():
            archive.write(p, p.relative_to(ROOT.parent))
print("=== COLLECTION COMPLETE ===")
print("Verified images:", len(manifest))
print("ZIP:", ZIP_PATH, "bytes:", ZIP_PATH.stat().st_size)
print("Categories:", json.dumps(summary["categories"]))
