# Mobile TPI/TPD, MJP and PVR: practical extraction findings

This note records a private reverse-engineering inspection of the Web WDF Viewer implementation at
https://github.com/co-stuff/web-wdf-viewer (files inspected: `TPIReader.js`, `MJPDecoder.js`,
`PVRDecoder.js`, `FileDetector.js`, and `C3Hash.js`). The repository has no declared license in
its repository metadata. It is used here as a diagnostic/reference tool only; its source is not copied
into the game or redistributed. The observations below describe file formats and behavior, not copied
implementation code.

## TPI/TPD index and payload

The reader expects a 0x30-byte TPI header whose first bytes are the ASCII signature
`NetDragonDatPkg`. The entry count is read as a little-endian 32-bit integer at offset 0x24.
Entries begin at offset 0x30. Each record is laid out as:

1. one-byte path length;
2. path bytes (Windows-1252 in the inspected implementation);
3. two bytes skipped/reserved;
4. four little-endian 32-bit values: uncompressed size, compressed size, second compressed-size
   copy, second uncompressed-size copy;
5. a four-byte little-endian offset into the paired TPD payload.

The implementation accepts a record only when both copies of the size values agree. Payload bytes
are sliced from the paired TPD at the recorded offset. If compressed and uncompressed sizes match,
the bytes are returned directly; otherwise the reader attempts raw DEFLATE decompression. The entry
path is lowercased, slash-normalized, and converted to a 32-bit resource UID using the Conquer
`StringToID` hash.

**Interpretation:** this TPI/TPD path is package indexing plus DEFLATE compression, not evidence of
encryption. A payload that fails DEFLATE may be another format, a malformed record, or a separately
protected resource; it must not automatically be labelled encrypted.

## MJP image payload

The MJP decoder recognizes the ASCII signature `MJP` and a minimum 36-byte header. It reads
little-endian fields at offsets 4, 8, 12, 16, 20, 24, 28 and 32. The first compressed block is
inflated and combined with the adjacent raw tail to reconstruct a JPEG stream. That JPEG is decoded
to RGBA. A second compressed block, when present, is inflated and applied as alpha. The inspected
decoder handles both 8-bit alpha (one byte per pixel) and packed 4-bit alpha (one nibble per pixel),
including small leading padding.

**Interpretation:** MJP is a container around JPEG color data and optional compressed alpha, not a
cipher by itself. Preserve alpha when exporting to PNG; flattening to JPEG will destroy transparency.

## PVR texture payload

The inspected decoder recognizes PVR v2 by the `PVR!` magic at byte offset 44 and PVR v3 by
little-endian magic `0x03525650` at byte offset 0. PVR v2 includes dimensions, pixel bit depth,
channel masks, and flags; common uncompressed 8/16/24/32-bit layouts are handled. PVR v3 includes
pixel format, dimensions, and metadata length. The viewer handles uncompressed channel-described
PVR v3 data, but reports common compressed formats such as PVRTC, ETC1 and DXT as unsupported.

**Interpretation:** a PVR file that the browser viewer cannot display may still be a valid compressed
texture. Do not discard it. Use a dedicated texture decoder (e.g. a tested PVRTC/ETC/DXT decoder) or
the original mobile renderer's texture upload path to recover it.

## Resource path hash

The viewer's `StringToID` implementation hashes UTF-8 path bytes after lowercasing and slash
normalization. The constants and rounds correspond to the Conquer C3 resource-name hash. This is a
name-to-UID mapping, not encryption and not a decryption key. It can help map index UIDs back to
paths only when the TPI path strings or another path catalogue are available.

## Next extraction steps for this project

- Reconcile our current Mobile TPI/TPD parser against the exact offsets, duplicate-size checks, path
  encoding and raw-DEFLATE behavior above; retain all rejected records in a diagnostic report.
- Export valid MJP entries to PNG with their alpha channel preserved.
- Inventory PVR v2/v3 formats and dimensions; send compressed formats to a dedicated decoder rather
  than treating them as corrupt.
- Correlate C3/MJP/PVR entries to model, character, equipment, map and interface resource paths.
- Only investigate encryption in native code if a valid resource is transformed by a loader routine
  beyond package extraction/decompression.

## Evidence boundary

This is a code-level format inspection of a third-party viewer and a cross-check against the
previously audited Mobile package structure. It is not a claim that every asset in the source archive
has been extracted, nor that the Mobile native decryption path has been recovered.
