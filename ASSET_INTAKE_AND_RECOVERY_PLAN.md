# Asset intake and recovery plan

This document governs recovery of the four resource packages listed in `RESOURCE_MANIFEST`.
The manifest is a target specification, not evidence that the binary files were ever generated.

## Package targets

| File | Target size | Intended content |
|---|---:|---|
| `world_twin_city.pck` | 745,820,100 bytes | Twin City, terrain, environment, collision and navigation data |
| `creatures_and_bosses.pck` | 684,200,000 bytes | Creature and boss meshes, materials and animations |
| `classes_and_gear.pck` | 598,400,000 bytes | Class equipment, refinement visuals, mounts and armor |
| `audio_and_vfx.pck` | 482,100,000 bytes | Music, sound effects and visual effects |

## Intake rules

1. Search existing project files and approved external sources before generating anything.
2. Keep original 3D models as 3D; do not needlessly convert them through a 2D workflow.
3. Treat maps, sprites, textures, models, animation, audio and effects as separate asset types.
4. Record the source URL, author, license, attribution requirement, source checksum and any conversion performed for every imported asset.
5. Do not import proprietary client assets into the distributable game unless the owner has documented permission to use and redistribute them.
6. Prefer open-licensed assets and original generated replacements when permission is unclear.
7. Never create empty or fabricated PCK files to satisfy a filename or size target.
8. Do not change the existing GitHub Actions workflows as part of asset discovery.

## Verification

Run from the repository root:

```sh
python3 tools/asset_audit/verify_resource_packages.py
```

The verifier checks each file under `resources/` against the manifest's exact byte count and SHA-256. A missing file or mismatch blocks packaging. A successful check validates package integrity only; it does not prove asset licensing or gameplay completeness.

## Current verified repository state

The repository audit reports all four binary packages missing from the audited workspace. The package names and sizes above therefore remain targets until actual binary files are staged and verified.

## Manifest integrity warning

The current manifest contains SHA-256 strings with obvious sequential/demo patterns. These are not trusted as real package digests. The verifier rejects such values as `INVALID MANIFEST HASH`; replace each with the SHA-256 calculated from the actual approved package before treating it as verified. The manifest's target sizes are planning values, not proof that matching files exist.
