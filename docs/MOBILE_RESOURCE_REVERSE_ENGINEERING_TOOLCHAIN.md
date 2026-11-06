# Conquer Online Mobile — Resource Decryption and Extraction Toolchain

Scope: the supplied **Conquer Online Mobile 1.1.2.3** source archive only. Desktop-client DAT cipher recipes, desktop WDF tools, and unrelated Conquer builds are not assumed compatible.

## Confirmed Mobile package layout

The successful forensic run for the supplied archive found these nested Android packages:

- `ConquerOnline/ConquerOnline-1.1.2.3.apk`
  - `assets/ConquerRes/data.tpi`: 263 index entries; no C3 entries in this package.
  - `assets/ConquerRes/ini/c3.wdb`: 28 named DBC entries.
- `ConquerOnline/install_time_1001.apk`
  - `assets/ConquerRes/c31.tpi`: 3,032 index entries; 1,952 C3 entries, all 1,952 with valid C3 headers.
  - `assets/ConquerRes/data1.tpi`: 3,374 index entries; no C3 entries in this package.
- Across the audited package set: 3 TPI/TPD pairs, 1,952 valid C3 resources, 18,394 MOTI chunks, zero C3 parse errors, zero audit errors.
- The extracted `c3.wdb` includes real index data such as `3dmotion.dbc` (266,953 records), `mountmotion.dbc` (60,703 records), and `weaponmotion.dbc` (458,283 records).
- `3DSkeleton.dbc` and `3DObjProp.dbc` are currently empty (8-byte RSDB headers with zero records). This is a real gap in the supplied package, not evidence that the mobile engine has no skeleton implementation.

These counts prove that a substantial part of the mobile resource pipeline is already readable from the supplied APKs. They do **not** prove that every asset is unencrypted or that all resources have been found.

## Mobile-specific tools found

### 1. Web WDF Viewer — useful reference, not an approved dependency

Repository: https://github.com/co-stuff/web-wdf-viewer

Its current source includes dedicated `TPIReader.js`, `MJPDecoder.js`, and `PVRDecoder.js`. The TPI reader understands the `NetDragonDatPkg` header and paired TPI/TPD index/data files; the MJP decoder reconstructs JPEG plus alpha data; the PVR decoder handles supported PVR2/PVR3 pixel layouts. The maintainer's Mobile-resource post specifically identifies TPI/TPD containing C3/MJP/PVR assets.

**License status:** no repository license is declared. Do not copy, bundle, redistribute, or merge its source into this project unless permission/license is established. It can guide format identification only; the project's existing parser remains independently maintained.

### 2. C3-Operator — C3 import/export reference

Repository: https://github.com/Tachyon-S/C3-Operator

Blender add-on for importing/exporting C3 models and their animations. Useful as an independent viewer/conversion cross-check after extracting individual C3 files. It is not a mobile APK decryptor and does not unpack TPI/TPD itself. Verify license/compatibility before adopting code.

### 3. Android static reverse engineering

- JADX (Apache-2.0): https://github.com/skylot/jadx — inspect DEX/Java code, string decryption wrappers, resource-loading calls, and JNI boundaries.
- Apktool (Apache-2.0): https://github.com/iBotPeaches/Apktool — decode manifest/resources/smali and inspect packaged assets.
- Ghidra (Apache-2.0): https://github.com/NationalSecurityAgency/ghidra — analyze ARM64 `.so` libraries for resource loaders, custom decompression/decryption, key derivation, and C3/MJP/PVR handling.
- Androguard: https://github.com/androguard/androguard — programmatic APK/DEX inspection and cross-reference searches.
- APKiD: https://github.com/rednaga/APKiD — identify known packers/obfuscators; a clean result does not rule out custom protection.

### 4. Runtime confirmation (only if static analysis is insufficient)

Frida: https://github.com/frida/frida — instrument the app's own resource-loading/decode functions in a controlled emulator/device session and capture buffers *after* the app has decoded them. This is the correct route for assets decrypted only in memory. It requires a compatible test device/emulator and an authorized app build; it is not a universal one-click decryptor.

## Required analysis sequence

1. Inventory all nested APKs, DEX files, ELF libraries, asset containers, and their hashes. Keep the exact source APK names and package/version identity in every report.
2. Decode DEX and Android resources with JADX/Apktool; search for `Cipher`, `MessageDigest`, `Base64`, `Inflater`, `ZipInputStream`, `AssetManager`, `System.loadLibrary`, JNI methods, and file/asset open functions.
3. Analyze each ARM64 library in Ghidra. Trace the call chain from TPI/TPD or asset reads to decompression/decryption and the final C3/MJP/PVR parser. Record constants, keys, seeds, IVs, and format versions only when verified in this Mobile binary.
4. Apply a decoder only to the exact matching format/version and validate output by magic, size, hashes, and parser success. Do not apply desktop Conquer DAT ciphers to Mobile files without proof.
5. If the app decodes data only at runtime, instrument the verified decode routine with Frida and capture the post-decode buffers. Never assume filename obfuscation alone is encryption.
6. Cross-check representative extracted C3/MJP/PVR outputs in independent viewers and retain the untouched originals.

## Important distinction

The classic Conquer Online desktop documentation describes TQ File Cipher and RSA-encrypted DAT files. Those algorithms and seeds are documented for particular desktop client patches; they are **not automatically the protection scheme used by Conquer Online Mobile 1.1.2.3**. Mobile-specific APK/ELF evidence must establish the actual method before any decryptor is selected.

## Current blockers

- The source archive has been audited successfully, but the newly added native-library inventory stage has not yet been run against the exact archive in Colab. No matching ARM64 game library has therefore been confirmed or ruled out from that source.
- The Mobile viewer's MJP/PVR implementation is in a repository with no declared license; it cannot be treated as a redistributable open-source dependency.
- No verified Mobile-specific decryption routine/key has yet been extracted from the target app's DEX or native libraries. Do not report encrypted resources as decrypted until that work is evidenced.
