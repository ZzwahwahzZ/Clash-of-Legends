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
