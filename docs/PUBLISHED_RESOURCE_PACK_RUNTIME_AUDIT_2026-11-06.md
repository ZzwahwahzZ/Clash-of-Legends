# Published Resource Pack Runtime Audit — 2026-11-06

## Purpose
Run the existing checksum and Godot runtime-content audit against the eleven published `resource-packs-v4` release assets.

## Scope
- Verify each published pack against `RESOURCE_MANIFEST` (exact byte size and SHA-256).
- Mount/inspect the packs using `tools/quality/audit_resource_pack_contents.gd`.
- Record actual runtime-visible 3D resources and missing registries/paths.
- Do not infer class/body mappings from filenames or model-number similarity.
- Do not approve placeholder geometry, unbound textures, incomplete rigs, or unverified animation playback.

## Character-source questions to resolve
The prior role-source audit found `3dsimplerole.ini`, role selection/creation records, and supporting role data, but did not find version-matched `3dobj.ini`, `3dtexture.ini`, or `3dmotion.ini`. The runtime audit must establish whether those registries or equivalent indexes exist inside the published packs. If absent, report the exact missing archive/source rather than substituting another game version.

## Findings from the first full PCK rehydration and WDB audit

All eleven published PCKs passed exact size and SHA-256 checks and mounted successfully in Godot 4.3. Rehydration exposed 1,946 C3 files and the original `c3.wdb` container at:

`resource_stage/world/apk_assets/ConquerOnline-1.1.2.3/assets/ConquerRes/ini/c3.wdb`

The WDB contains the missing authoritative tables:
- `ini/3DObj.dbc`: 3,316 object-ID to C3-path records.
- `ini/3DTexture.dbc`: 53,254 texture-ID to PVR-path records.
- `ini/3DSimpleObj.dbc`: 797 simple-object assemblies.
- `ini/3DMotion.dbc`: 266,953 motion-ID to C3-path records.
- Additional motion tables cover weapon, armet, misc and mount actions.

The simple-object join currently resolves both object and texture references for 735 of 808 parts (90.97%). There are 49 unresolved object IDs and zero unresolved texture IDs in that particular simple-object join. Equipment-family tables have separate unresolved references and must not be conflated with this percentage.

The audit also found a 7,908-byte `ROPT` RolePart table with 12 records. Its record layout is not yet validated; the parser now emits a raw bounded probe rather than assigning guessed field meanings.

The first runtime PCK audit found zero GLB/GLTF files and no verified complete-character mappings in the published pack baseline. The separate C3 conversion pipeline is now running against the recovered C3/PVR paths. Conversion outputs still require Godot import, rig/action, material, fit and visual review before they can be approved for the game.

## Acceptance
A successful checksum audit is not visual approval. A successful resource listing is not a character mapping. Report separate results for package integrity, resource discoverability, model/texture joins, rig/action compatibility, and actual Godot/mobile rendering.
