# External Asset Intake Matrix — 2026-11-06

This is a candidate-source register, not an approval list. No candidate becomes a production asset until it passes visual inspection, topology/material/UV checks, skeleton and animation compatibility, Android performance checks, and in-game scale tests. Native C3 resources remain the first choice whenever the original source asset can be recovered and converted.

## Candidate sources

| Family | Candidate source | License / terms | Intended use | Current status |
|---|---|---|---|---|
| Mounts | Existing five image-reconstructed mount GLBs in `ZzwahwahzZ/Conquer-Mobile-Assets.` | Verify source image rights separately; generated meshes are reconstruction candidates | Geometry/shape comparison, conservative cleanup, later rigging and tack integration | NOT APPROVED; Blender audit rerun queued |
| Mount reference | Quaternius Horse via Poly Pizza/KivLoft: https://kivloft.com/files/poly-pizza-qvtrsg9pzf | CC0 1.0; free commercial use; page includes attribution metadata though CC0 does not require it | Low-poly animation/rig reference and fallback candidate only | NOT DOWNLOADED OR TESTED |
| Helmets / shields | Blacksmith Armor Pack: https://sotudios.com/Assets/Blacksmith-ArmorPack/ | CC BY 4.0; attribution required; check redistribution terms | Separate helmet/shield candidates; inspect silhouette, scale, UVs, materials | NOT DOWNLOADED OR TESTED |
| Weapons | Polyy.AI 25 Fantasy Weapons: https://polyyai.itch.io/3d-fantasy-weapons-pack | CC0 | Weapon shape library; prioritize low LOD for mobile, preserve high LOD for inspection | NOT DOWNLOADED OR TESTED |
| Creatures / monsters | Gobkit Free Animal Pack + Vol.2: https://gobkit.com/freebies and https://gobkit.com/api/free | CC0 1.0; GLB; rigged; baked 24 FPS timelines | Supplemental monster/creature candidates only where visual theme fits; retarget/test animation clips | Manifest verified; files not yet imported |
| Enemy / NPC archetypes | Gobkit Free Character Pack Vol.3: https://gobkit.itch.io/gobkit-free-character-pack-vol-3 | CC0 1.0; GLB; rigged; named Idle/Walk/Run/Death/Hit/Attack/Special clips | Supplemental silhouettes and rig/animation references; not a substitute for class-specific hero designs | Source details verified; files not yet imported |
| Image-to-3D | TripoSR official Space: https://huggingface.co/spaces/stabilityai/TripoSR | MIT model; output is untextured; one-view reconstruction has inferred unseen surfaces | Prototype missing props/shape candidates, followed by UV/material/rig work | Space parameter call returned HTTP 503 in this session; no generation performed |

## Quality gates

1. Preserve original assets and source files. Never overwrite a source GLB during repair.
2. Keep disconnected islands unless a visual/source comparison proves they are unwanted (mount tack and ornaments may be separate components).
3. Reject or quarantine broken transforms, missing materials/textures, UV failures, inverted normals, excessive mobile triangle counts, malformed skeletons, and unusable animation clips.
4. Do not accept a model based only on successful import or file existence. Require lit previews, multiple angles, dimensions, and an in-engine test.
5. Record provenance, license, source URL, file hash, polygon counts, texture sizes, skeleton/animation metadata, and the exact game role for every approved asset.
6. Keep mobile budgets in mind: create/use LODs and texture atlases; avoid adding all high-resolution source assets to the Android package.
7. Do not hotlink third-party assets at runtime. Bundle only reviewed and licensed assets into the project.

## Immediate work queue

- Repair and visually inspect the five existing mount reconstruction candidates.
- Continue original C3 helmet/weapon/equipment conversion and family inventory.
- Acquire and inspect CC0 weapon and character/creature candidates; compare them to the project's art direction before integration.
- Inspect the CC BY 4.0 armor pack and retain its required attribution if any item is approved.
- Treat TripoSR as an optional external generation path, not a dependency; retry only when the public Space is available.

## Source notes

- Gobkit's public manifest documents CC0, self-contained GLB files, baked animation timelines, and warns that runtime hotlinking is only for prototypes: https://gobkit.com/api/free
- TripoSR's one-image reconstruction has limits for unseen backs, thin geometry, transparency, and reflective surfaces; all outputs require inspection.
