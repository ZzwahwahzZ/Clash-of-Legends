# Third-party parser notice

This audit-only utility uses the sandbox-data crate from Preservation CO Client by the Preservation CO Client contributors, pinned to commit 090541d10d8a7d001fe804dd1c23325c344f861d.

- Repository: https://github.com/deklol/Preservation-CO-Client
- License: Apache License 2.0
- Scope: build-time parsing and inspection of C3 model files only. The parser is not included in the Android game runtime.
- The converter and report format in this repository are separate project code. No upstream game assets are copied from the parser repository.

See LICENSE-APACHE-2.0.txt for the license text.

## PVRTC texture decoder

The build-time PVR v2 audit uses `texture2ddecoder` 1.0.6 to decode legacy PVRTC1 4bpp source textures. The package and PVRTC codec are MIT-licensed; see https://github.com/K0lb3/texture2ddecoder and its bundled LICENSE. It is installed only in the audit workflow and is not shipped in the Android game.


## C3 PHY extension compatibility overlay

The audit and resource-pack workflows apply the repository-owned patch at `third_party_patches/c3-mesh-extension-tags.patch` to the pinned Apache-2.0 `sandbox-data` parser in the temporary build workspace. It accepts the observed four-byte C3 PHY markers `BILB`, `BIB2`, `BIB3`, and `BIB4`, preserves the existing `2SID` flag, and recognizes optional `STEP1`/`STEP2` UV blocks. The patch is not a runtime dependency and no upstream parser code is shipped in the Android game.
