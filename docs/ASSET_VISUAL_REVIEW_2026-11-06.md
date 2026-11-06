# Visual Asset Review — 2026-11-06

## Mount candidates

The external mount repair run `42132407910` completed successfully and produced five conservative-repair GLBs plus the original reference screenshots. This is a successful audit pipeline, not successful asset repair.

Visual inspection of the generated meshes shows all five candidates are thin, slab-like reconstructions rather than usable horse/mount meshes. Geometry metadata also confirms:
- zero material slots and zero UV layers on all five;
- zero armatures and zero animation actions;
- 222–579 boundary/non-manifold edges per candidate;
- conservative cleanup made no meaningful geometry changes (no degenerate faces were present).

**Decision: reject all five for runtime use.** Preserve the originals and audit artifact for provenance only. Do not add them to the mount runtime catalog.

## Original C3 equipment candidates

The C3 audit run `42131464090` completed successfully. Its report artifact contains 42 diagnostic renders:
- 18 armet/headgear-family models;
- 8 hair models;
- 2 head components;
- 14 weapon models (one model, `610000`, failed the geometry gate and is excluded).

The visual contact sheets show detailed static meshes with UVs and embedded PBR base-color textures. The weapon candidates include bows, polearms, blades, a pistol-like weapon and paired weapons. These are far more useful than the reconstructed mount slabs.

The source-join artifact shows the Mobile weapon translation table joins 8,264 item records to MESH records. Exact converted C3 mesh-path matches are promoted into a runtime weapon visual candidate catalog only when the corresponding converted GLB exists. The initial source-mapped subset is intended for item-ID lookup.

## Acceptance boundaries

- Exact item-to-source mesh mapping is sufficient to identify a weapon candidate.
- It does **not** prove character-class compatibility, hand socket fit, grip orientation, combat animation alignment, or final in-game visual acceptance.
- Headgear and hair remain preview-only until their item-to-model translation and head socket mapping are proven.
- No external reconstructed mount is approved. The original mount MESH/motion join remains the preferred route.
- The original project assets and C3 source are preserved; generated GLBs are internal runtime candidates and are not published in a public release.

## Workflow evidence

- Mount repair and visual audit: run `42132407910`, artifact `External-Mount-Repair-Candidates`.
- C3 model conversion and equipment previews: run `42131464090`, artifact `C3-Model-Conversion-Reports`.
- Mobile item/MESH/motion join: run `42131464080`, artifact `Equipment-Item-Mount-MESH-Join-Audit`. Its join/report steps succeeded, but the overall PCK workflow was cancelled before C3 conversion and PCK export.

## Next runtime gate

The runtime catalog will expose exact source-joined weapon candidates by Mobile item ID. A weapon is only visually approved for a given class after a Godot in-game attachment preview confirms grip, scale, orientation, and clipping.
