# C3 Asset Toolchain Evaluation

**Scope:** Conquer Online Mobile 1.1.2.3 C3 models, motion files, textures, and native skeleton metadata.
**Status:** Research and compatibility evaluation. No third-party converter is approved for production export yet.

## Evidence from the current resource-pack audit

The Android runtime audit mounted all 11 PCK files and found:

- 1,946 source `.c3` files in the staged source tree.
- 13,131 unique motion paths across the source motion tables.
- 24 converted GLB model files in the runtime model catalog.
- 24/24 GLBs loaded and had renderable geometry; 9 had animation tracks.
- 0/24 imported GLBs exposed a Godot Skeleton3D.
- 0 verified character-class mappings were present, so all 11 playable classes remained correctly blocked by the runtime content gate.

This is a conversion and mapping coverage gap, not proof that the original source contains no character assets. The current Rust C3 batch exporter creates a structural motion-pairing report, but it only exports a small proof-of-concept set for two body models (looks 7 and 8, weapon token 500, action tokens 100/110/120). The broad pairing report is not yet a runtime-ready character/animation library.

## Tool evaluation

### 1. Preservation CO Client C3 parser — current production baseline

- Repository: https://github.com/Preservation-CO-Client/Preservation-CO-Client
- The pinned `sandbox-data` C3 parser is Apache-2.0 and is already used by `tools/c3_audit`.
- Keep it as the reproducible, license-compatible baseline for parsing and automated tests.
- Its current exporter must not be treated as a complete Conquer rig importer: the produced GLBs have not passed skeleton, attachment-socket, and full-motion acceptance.

### 2. C3 Operator for Blender — skeletal cross-check candidate

- Repository: https://github.com/Tachyon-S/C3-Operator
- Release documented: v2.3.1; Blender 2.8+.
- Its importer reads PHY mesh chunks, two vertex bone-index/weight channels, MOT chunks, and can create a Blender armature and import an animation file separately.
- The inspected importer creates bones from per-bone position data and vertex groups, but does not establish the complete named parent hierarchy needed for verified retargeting. Its own README lists bone-system translation as unfinished and notes scale/orientation normalization work remains.
- No explicit repository license file was found during this evaluation. Do not copy, redistribute, or embed its code until licensing is verified. It may be evaluated as an isolated reference tool only if its terms permit the intended use.

### 3. C3 Blender Add-On — PHY/keyframe compatibility cross-check

- Repository: https://github.com/abdouthematrix/c3-blender-addon
- Its README documents PHY, PHY3, PHY4; KKEY, ZKEY, XKEY and legacy keyframes; multiple PHY objects; texture loading; and shape-key animation baking.
- The inspected importer explicitly comments out armature creation, mesh skinning, and skeletal animation in favour of shape keys. Therefore it is useful for detecting PHY/keyframe variants the current parser may miss, but it is **not** a replacement for the skeletal runtime pipeline.
- No explicit repository license file was found during this evaluation. Do not copy, redistribute, or embed its code until licensing is verified.

### 4. C3Studio — visual inspection reference

- Repository: https://github.com/abdouthematrix/C3Studio
- A WPF/MonoGame viewer for C3 models, NPC/simple-object INI data, textures, and motion playback. It requires Windows and .NET 8 according to its README.
- No explicit license file was found during this evaluation. Treat it as an external inspection reference, not a dependency or code source, until licensing is verified.

### 5. Ghidra — native engine reverse engineering

- Repository: https://github.com/NationalSecurityAgency/ghidra
- Use when the matching Mobile ARM64 client library is present and its provenance is verified.
- Target symbols/behaviour already identified from native-engine evidence include C3DSkeletonX load/version routines, bone names, parent IDs, reference poses, pivots, and socket lookup.
- Do not invent a substitute hierarchy when the native library or source records are absent.

### 6. ImHex — binary-format inspection

- Repository: https://github.com/WerWolv/ImHex
- Use Pattern Language templates to inspect C3/DBC/DAT structures, validate offsets, and compare multiple source samples.
- Patterns must be derived from verified samples and checked against the parser; a hex template alone does not prove semantic meaning.

## Decision and next engineering sequence

1. Keep the Apache-2.0 parser as the baseline and preserve source hashes/provenance.
2. Add an isolated Blender compatibility pass over representative samples from every discovered PHY subtype and keyframe family. Compare mesh counts, vertex/index counts, UVs, texture references, frame counts, and animation deformation against the Rust parser. Do not accept shape-key output as a skeletal rig.
3. Expand exact source joins from `3dsimplerole.ini`, `rolechoose.ini`, `3DObj.dbc`, `3DSimpleObj.dbc`, `RolePart.dbc`, and motion tables. Keep unresolved class/gender links explicitly unresolved.
4. Run the new nested-APK native-library inventory from the Colab notebook. If the matching Mobile ARM64 native library is present in the supplied archive, inspect it with Ghidra; if not, record that absence and do not infer the native hierarchy. Recover bone names, parent IDs, reference pose, pivots, and sockets from source-backed records.
5. Only then generate named parented skeletons and bind motion clips. Reject non-TRS/sheared transforms rather than silently flattening them.
6. Import the result into Godot and require Skeleton3D presence, valid skin weights, all expected mesh parts, correct sockets, animation playback, and visual review before approving a character.
7. Keep all third-party tools outside the shipped APK. Only accepted project-owned converted assets enter runtime PCKs.

## Explicit non-goals

- Do not replace original Conquer assets with generic marketplace models.
- Do not label a candidate model as a class/gender based on numeric look IDs alone.
- Do not treat an imported Blender shape-key animation as proof of the original bone hierarchy.
- Do not bypass the all-class content gate or the visual blockout gate to obtain a green build.


### 7. OpenFairyGUI — FairyGUI V7 package reader (MIT)

- Repository: https://github.com/OpenFairyGUI/OpenFairyGUI
- Package: `@openfairygui/core@0.7.0`; license MIT; Node.js 22+.
- Its `BinaryReader` reads published FairyGUI `.fui` packages and reconstructs package resources, atlas/sprite mappings, component display lists, controllers/pages/actions, transitions, gears, relations, and scroll settings.
- The protocol documentation is explicitly V7 only. Therefore the Colab pipeline first inventories each `.fui` header and only submits files with the exact `FGUI` magic and version 7 to the reader. Unknown or older files are retained as unknown/other-version; they are not force-parsed as FairyGUI.
- The reader is used to create a private structural inventory, not to rewrite or replace the original UI. The original atlas images and their links still need separate source-backed validation before Godot integration.
- The package is not shipped in the APK; only accepted project-owned UI resources may enter the game.

Repository: https://github.com/OpenFairyGUI/OpenFairyGUI
Protocol: https://fairygui.dev/en/fairygui-binary-package-format


## 8. Conquer-specific encrypted and hidden-resource recovery (mandatory workstream)

This workstream is separate from ordinary format conversion. A file is not considered fully recovered merely because its extension is known, it appears in an index, or a parser can read its first records.

### 8.1 Source-grounded format families and specialist references

| Family | What must be recovered | Specialist reference / method | Acceptance evidence |
|---|---|---|---|
| TPI + TPD | Complete index, every path, stored/compressed payloads, alternate compression and malformed records | Conquer-specific TPI/TPD readers; compare the original mobile reader behavior with independent parsers | Every declared entry accounted for; exact bounds, sizes, hashes and decompression status |
| WDF | Hidden/hash-addressed files without path names | Conquer WDF readers and hash enumeration; test known path hashes against the archive index | Index count reconciles; all entries extracted or explicitly classified |
| DNP | Versioned package index, including version 1001 XOR-masked UID/size/offset fields | Conquer DNP reader; independently verify header, XOR constants and file bounds | Version-specific parser tests and per-entry SHA-256 |
| WDB / DBC | BDMG WDB entries; RSDB, MESZ and other DBC payloads; unknown table encodings | Conquer WDB tools, binary templates and native-client cross-checks | All named entries extracted; each DBC classified and parsed or preserved as opaque |
| TQ File Cipher | Files specifically identified as using the symmetric TQ cipher, with the correct per-file seed | Conquer Online Development Wiki cipher documentation and patch-specific seed catalogue | Decrypted output passes format-specific structural checks; never guess a seed |
| RSA-protected DAT | RSA-wrapped, gzip-compressed records where the matching client embeds the public key | `conquer-rsa-patcher` key extraction/decryption workflow; analyze the exact matching client binary | Cipher identification, key provenance, block/padding checks and successful decompression |
| C3 / MOTI / skeleton | Every model, motion, PHY/MNEW/SMOT/SCEN/PTCL chunk, skeleton and socket relation | C3Studio as a format/reference viewer only until its license is confirmed; existing C3 parser plus native ARM64 analysis | No silent chunk skips; exact source ID → model/rig/motion mapping and runtime animation proof |
| MJP / PVR | Texture payloads, palette/format metadata, alpha and atlas relations | Conquer Mobile resource-viewer research; independent PVR/MJP decoders | Dimensions, pixel format, alpha and atlas references verified against source |
| DMap / map data | 7z-contained and standalone DMap variants, tiles, objects, collision and links | Conquer map-specific viewers/parsers; inspect every variant rather than assuming one schema | Map geometry and object counts reconcile; in-engine visual comparison |
| Audio / animation sidecars | OGG and other audio, ANI and sidecar motion files | FFmpeg/ffprobe plus format-specific animation readers | Codec/duration/sample-rate and animation references catalogued; playback verified |

### 8.2 Tools discovered and licensing boundary

- **C3Studio** (`abdouthematrix/C3Studio`): a Conquer-specific viewer with WDF, TPI/TPD and DNP package readers, plus C3 model/motion parsing and INI-based NPC/simple-object browsing. Its source demonstrates TPI v1000, TPD zlib/raw-deflate handling, WDF path hashing, and DNP v1000/v1001 index decoding. No repository license file was confirmed during this review. Therefore it is a research/reference candidate only: do not copy, vendor, compile into, or redistribute its code until a compatible license is verified. Its parser also skips malformed TPI size-pair entries, so it cannot be the sole completeness oracle.
- **OpenFairyGUI**: MIT-licensed, but only useful for files proven to be FairyGUI binary V7. It is not a generic FUI decryptor and must not be applied to unknown UI formats.
- **Ghidra**: use on the exact matching Android ARM64 libraries to identify file open/decrypt/decompress routines, embedded keys/seeds, path-hash functions and format dispatch. A symbol or function name alone is not proof; validate against known source files.
- **ImHex**: use for repeatable binary layouts and signatures for unknown DBC/TPI/TPD/DNP variants, with sample-backed patterns and bounds checks.
- **QuickBMS**: use only when a matching, source-backed extraction script exists; it is not a universal decryptor.
- **Conquer RSA patcher / TQ cipher references**: use only for files and client versions explicitly matched to the documented cipher. Desktop patch seeds and keys must not be presumed valid for the Android 1.1.2.3 source.

### 8.3 Mandatory recovery procedure

1. Inventory every archive and nested archive by signature, not extension alone. Preserve the original bytes and compute SHA-256 before and after every stage.
2. Enumerate all container indexes (including hashed entries with no visible filename). Reconcile declared counts, parsed counts, duplicate IDs, duplicate paths, overlapping ranges, out-of-bounds offsets, gaps, and size-pair mismatches.
3. Identify compression and encryption independently. Test stored, zlib, raw deflate, gzip, LZ-family and other candidates only from header/client evidence; never silently try arbitrary transformations and accept plausible-looking output.
4. For encrypted formats, locate the matching client routine in the exact supplied Android build, recover the algorithm/key/seed from public client code or the binary, and validate against multiple known records. Keep the encrypted original beside the decrypted derivative.
5. Recursively inspect extracted payloads for nested archives, embedded files, signatures, trailing data and concatenated records. Include extensionless and misleadingly named files.
6. When a parser rejects or skips an entry, preserve its raw bytes and create a failure record with source container, index, offset, declared sizes, hash, parser/version and reason. A malformed record is not permission to discard the bytes.
7. Compare independent implementations and known-good viewers. Resolve disagreements before integration.
8. Produce an extraction completeness report by source archive and format. No resource family is marked complete while unresolved entries, unknown encrypted payloads or unexamined nested containers remain.

### 8.4 Current source-specific evidence and unresolved gaps

The successful original-resource audit artifact for `extracted-assets-001.zip` reports:
- one WDB with 28 named DBC entries;
- three TPI/TPD package pairs;
- 1,952 C3 entries with valid C3 headers and zero C3 payload parse errors in the audit;
- 18,394 MOTI chunks and 842 MNEW chunks;
- 355 malformed TPI index records in `assets/ConquerRes/c31.tpi` and 156 in `assets/ConquerRes/data1.tpi`;
- 28/28 WDB entries named, but several DBC payloads still require format-specific decoding.

These counts describe the inspected archive and parser output only. They do not prove that every mobile resource was found or decrypted. The malformed TPI records are now a priority: recover their raw index bytes and associated TPD ranges before accepting any TPI export as complete. The 889-vs-13,131 motion-path coverage gap remains open and must be reconciled against all package indexes, DBC references, client-side hash lookups and any additional motion containers.

### 8.5 Definition of done

- Every source container has a complete entry ledger, including unknown/extensionless records.
- Every encrypted item is either decrypted with a version-matched, validated method or explicitly preserved and reported as unresolved; no guessed keys/seeds.
- No unexplained skipped records, TPI malformed entries, parser exceptions or silent chunk skips remain.
- Extracted assets have stable source paths, source hashes, decoded hashes, format metadata and provenance.
- Model, motion, texture, UI, map, audio and gameplay-data references reconcile to the source catalog and are verified in the Godot runtime.


### 8.6 Newly confirmed specialist lead: TQ Package Manager and full-format TPI/TPD gap

The Conquer-specific TQ Package Manager thread documents WDF, DNP, WDB and TPI/TPD extraction, plus a WDF/DNP brute-force filename-list generator. More importantly, the format author states that the old public extractor does **not** support the full TPI/TPD format (including some CO3 packages), while he later wrote newer private Rust CLI tools after fully reversing the formats. The author explicitly says TPI names are already encoded in the paired TPI index, so brute-force is unnecessary for TPI/TPD; brute-force is relevant to hash-addressed WDF/DNP entries and has false positives due to hash collisions.

Action:
1. Treat the old public package manager as a legacy comparison tool, not the completeness solution.
2. Prioritise reproducing the newer full TPI/TPD format behavior from our exact mobile samples, using the private-tool description as a lead and our 355 + 156 malformed-entry cases as test fixtures.
3. Check whether the format author or maintainers can provide a compatible public tool, a documented format update, or permission to use a sample-based specification. Do not wait on private tooling; continue independent reverse engineering.
4. For WDF/DNP only, add controlled candidate-name/hash enumeration using known INI/ANI/DBC references and a bounded dictionary. Record collisions and validate file signatures; never count brute-force hits as confirmed assets without validation.
5. Keep two separate metrics: (a) named TPI/TPD index recovery completeness, and (b) hash-only WDF/DNP discovery coverage.

This lead changes the priority order: full TPI/TPD parsing and malformed-record recovery come before expanding generic extension-based scanning.
