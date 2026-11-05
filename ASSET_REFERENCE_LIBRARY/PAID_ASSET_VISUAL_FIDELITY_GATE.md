# Paid Equipment & Mounts — Visual Fidelity Acceptance Gate

**Status: BLOCKED / NOT APPROVED**  
**Applies to:** every paid/premium weapon, armor piece, helmet, garment, fashion, mount, mount saddle/tack/ornament, and attached visual effect.

## Non-negotiable visual target

For these categories, the approved in-game asset must preserve the exact Conquer Online Mobile source appearance: model silhouette and proportions, geometry details, engravings, pattern placement, colors, texture artwork, material response, transparency, ornament placement, and distinctive effects. No redesign, recolor, simplification, generic replacement, or “close enough” substitute is permitted.

Technical work may improve import reliability, UV correctness, normal handling, material setup, mipmapping, lighting calibration, and runtime performance only when those changes do not alter the source identity or visible design.

## Acceptance is per item, not per category

An item can be marked `APPROVED` only when all of the following are present:

1. **Identity and provenance:** stable item/model ID; category; exact original source path; source version; source checksum; ownership/permission and intended-use record.
2. **Geometry:** complete expected mesh/part inventory; no missing helmet crest, armor plate, weapon fitting, mount tack, or ornament; no broken normals, gaps, clipping, z-fighting, or unintended deformation.
3. **Texture assignment:** each mesh/part is mapped to the correct source texture and texture region; UV coordinates and atlas rows are checked; no stretched, mirrored, offset, bleeding, or repeated fragments; original palette and pattern remain unchanged.
4. **Material behavior:** opaque/alpha parts, alpha cutoff/blending, vertex color, double-sided surfaces, roughness/metallic response, and mip levels are checked against the source.
5. **Visual comparison:** source and in-game render are compared at equivalent angles and scale (front, back, both sides, and close-up details). Screenshots and reviewer notes are retained.
6. **Runtime check:** inspect at normal gameplay camera distance and close-up, under neutral and gameplay lighting, including animation/equipment attachment where relevant.
7. **Rights gate:** the exact source may ship only when the project's rights/permission cover that distribution. A private technical conversion is not permission to publish proprietary files.

Missing evidence means `UNRESOLVED — NOT APPROVED`, never implicit approval.

## Current C3/PVR pipeline evidence (2026-11-05)

Latest verified CI run: [Audit original C3 models — run 42071562646](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42071562646)  
Commit: `90a002d4459a4e6c67d5659fc1c2eccb3c559876`  
Artifact: [C3-Model-Conversion-Reports](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42071562646/artifacts/13435852656)

- Godot import/validation and the render step both completed successfully.
- The audit report records 1,904 source model records, 569 converted outputs, 497 skipped records, and 40 parser failures (the failures are in effect paths).
- The 569 converted outputs are categorized as: 492 effects, 42 equipment, 24 characters, 4 world assets, 1 monster, and 6 motion proof outputs.
- 1,060 PVR textures decoded with zero decoder failures in this C3 audit.
- Six male/female Idle, Walk, and Run VAT proof clips validated; 72 deforming VAT mesh records were validated, with no missing expected clips.

**These results prove a technical conversion/import path and selected animation proofs. They do not prove premium item identity, complete equipment coverage, texture-to-mesh correctness, visual parity, or production art quality.**

## Matching mobile source-index evidence

A separate metadata-only audit of the same Conquer Online 1.1.2.3 source set located `ini/c3.wdb` (SHA-256 `5e2412beb9000d38578f88f7ba68ce17c17448f376d13e8fd5f36d9234a35f80`). It parsed the C3 object-path index (`3DObj.dbc`: 3,316 records) and the simple-object composition table (`3DSimpleObj.dbc`: 797 records). It also detected 25,405 weapon records, 3,041 armet records, 1,376 mount records, and 53,254 3D texture records, but the current audit only records those tables' headers/counts where their record layouts are not yet validated. **These counts are not a verified paid-item catalogue and do not yet map shop entries to exact visual assets.**

The source-index audit report is available in [Source-Audit-Reports run 42000137006](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42000137006). The next data task is to safely decode and validate the relevant item-table schemas, then cross-reference their IDs with the C3 object/texture and mount records before any visual approval.

## Explicit gaps found in this audit

- No mount-category C3 output was produced in this audit (`mounts/c3` count: 0). Mounts and their tack/ornaments remain unresolved here.
- The 42 equipment outputs are not a complete purchasable wardrobe. The report contains a limited set of `armet`, `hair`, `head`, and `weapon` paths; it does not establish the complete set of armor, garments, fashions, weapon tiers, or paid item IDs.
- The current conversion report does not contain a per-item source-to-render visual comparison or a verified mapping from paid shop entries to C3 model/texture IDs.
- The current renderer/exporter proof is not a substitute for reviewing atlas UV placement, hard-edged helmet/armor texture artifacts, material response, and small ornamental details on each actual item.

## Next required work before character or item approval

1. Build a source-backed item registry from the matching mobile-version item/shop data and source asset index. Record paid status only when supported by the matching version's data; do not infer it from a model ID.
2. Join every registry entry to its exact model, texture(s), attachment point, and effects. Keep unmatched entries in an explicit missing-assets report.
3. Produce per-item texture/UV diagnostic renders and turntable/contact sheets. Include helmet and armor close-ups because sharp streaking, atlas bleeding, and incorrect mesh-to-texture assignment are known review concerns.
4. Correct the mapping/import issue at source. Do not paint over, recolor, or otherwise hide a mismatch.
5. Repeat source-vs-runtime visual checks and retain evidence before changing an item to `APPROVED`.

## Status vocabulary

- `SOURCE_VERIFIED`: original source file and provenance are identified.
- `CONVERTED_TECHNICALLY`: parser/exporter/importer accepted the asset.
- `VISUAL_REVIEW_REQUIRED`: geometry, UV, texture, material, or comparison checks remain.
- `UNRESOLVED — NOT APPROVED`: exact source, mapping, permission, or visual evidence is missing.
- `APPROVED`: every per-item acceptance check above passed and evidence is retained.

No category-wide approval is permitted from aggregate counts alone.
