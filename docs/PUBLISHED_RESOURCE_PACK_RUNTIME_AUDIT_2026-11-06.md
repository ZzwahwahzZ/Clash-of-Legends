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

## Acceptance
A successful checksum audit is not visual approval. A successful resource listing is not a character mapping. Report separate results for package integrity, resource discoverability, model/texture joins, rig/action compatibility, and actual Godot/mobile rendering.
